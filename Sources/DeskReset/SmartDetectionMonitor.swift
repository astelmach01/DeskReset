import AVFoundation
import Foundation
import Vision

@MainActor
final class SmartDetectionState: ObservableObject {
    @Published var status: SmartDetectionStatus = .off
    @Published var facePresent = false
    @Published var lastFaceSeenAt: Date?
    @Published var lastAwayStartedAt: Date?
    @Published var lastError: String?

    var awaySeconds: TimeInterval {
        guard !facePresent, let lastAwayStartedAt else { return 0 }
        return Date().timeIntervalSince(lastAwayStartedAt)
    }

    func markFacePresent(_ present: Bool) {
        facePresent = present
        if present {
            status = .present
            lastFaceSeenAt = Date()
            lastAwayStartedAt = nil
        } else {
            if lastAwayStartedAt == nil {
                lastAwayStartedAt = Date()
            }
            status = .away
        }
    }

    func stop() {
        status = .off
        facePresent = false
        lastAwayStartedAt = nil
    }

    func fail(_ message: String) {
        status = .unavailable
        lastError = message
    }
}

enum SmartDetectionStatus: String {
    case off
    case requestingPermission
    case present
    case away
    case unavailable
}

final class SmartDetectionMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let state: SmartDetectionState
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "deskreset.smart-detection", qos: .utility)
    private var isRunning = false
    private var lastProcessedAt = Date.distantPast

    init(state: SmartDetectionState) {
        self.state = state
        super.init()
    }

    func start() {
        guard !isRunning else { return }
        let state = state
        Task { @MainActor in
            state.status = .requestingPermission
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            let state = state
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndStart()
                } else {
                    Task { @MainActor in
                        state.fail("Camera permission denied")
                    }
                }
            }
        default:
            let state = state
            Task { @MainActor in
                state.fail("Camera permission unavailable")
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        session.stopRunning()
        isRunning = false
        let state = state
        Task { @MainActor in
            state.stop()
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSessionIfNeeded()
                self.session.startRunning()
                self.isRunning = true
            } catch {
                Task { @MainActor in
                    self.state.fail(error.localizedDescription)
                }
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard session.inputs.isEmpty else { return }
        session.sessionPreset = .low

        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw SmartDetectionError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw SmartDetectionError.cannotAddInput
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            throw SmartDetectionError.cannotAddOutput
        }
        session.addOutput(output)
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessedAt) >= 1 else { return }
        lastProcessedAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let state = state
        let request = VNDetectFaceRectanglesRequest { request, _ in
            let faces = request.results as? [VNFaceObservation] ?? []
            let facePresent = !faces.isEmpty
            Task { @MainActor in
                state.markFacePresent(facePresent)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
    }
}

enum SmartDetectionError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: return "No camera is available"
        case .cannotAddInput: return "Could not start camera input"
        case .cannotAddOutput: return "Could not start camera output"
        }
    }
}
