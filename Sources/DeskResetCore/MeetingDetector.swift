import Foundation

public struct MeetingSignal: Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String?
    public var windowTitle: String?

    public init(appName: String, bundleIdentifier: String?, windowTitle: String?) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
    }
}

public enum MeetingDetectionReason: String, Equatable, Codable, Sendable {
    case dedicatedCallApp
    case meetingWindowTitle
}

public struct MeetingDetection: Equatable, Codable, Sendable {
    public var appName: String
    public var reason: MeetingDetectionReason
    public var detail: String?

    public init(appName: String, reason: MeetingDetectionReason, detail: String?) {
        self.appName = appName
        self.reason = reason
        self.detail = detail
    }
}

public enum MeetingDetector {
    public static func detect(from signals: [MeetingSignal]) -> MeetingDetection? {
        for signal in signals {
            if isDedicatedCallApp(signal) {
                return MeetingDetection(
                    appName: signal.appName,
                    reason: .dedicatedCallApp,
                    detail: signal.bundleIdentifier
                )
            }
        }

        for signal in signals {
            if let title = signal.windowTitle, isMeetingTitle(title) {
                return MeetingDetection(
                    appName: signal.appName,
                    reason: .meetingWindowTitle,
                    detail: title
                )
            }
        }

        return nil
    }

    private static func isDedicatedCallApp(_ signal: MeetingSignal) -> Bool {
        let bundle = signal.bundleIdentifier?.lowercased() ?? ""
        let app = signal.appName.lowercased()
        let callBundles: Set<String> = [
            "us.zoom.xos",
            "com.microsoft.teams",
            "com.microsoft.teams2",
            "com.apple.facetime",
            "com.cisco.webexmeetingsapp",
            "cisco-systems.spark"
        ]
        if callBundles.contains(bundle) {
            return true
        }
        return ["zoom", "microsoft teams", "facetime", "webex"].contains { app.contains($0) }
    }

    private static func isMeetingTitle(_ title: String) -> Bool {
        let normalized = title.lowercased()
        let exactSignals = [
            "google meet",
            "meet.google.com",
            "zoom meeting",
            "microsoft teams meeting",
            "webex meeting",
            "slack huddle"
        ]
        if exactSignals.contains(where: { normalized.contains($0) }) {
            return true
        }
        if normalized.contains("huddle") {
            return true
        }
        return normalized.contains("whereby") || normalized.contains("around meeting")
    }
}
