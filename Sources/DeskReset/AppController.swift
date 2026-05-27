import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import DeskResetCore
import SwiftUI
import UserNotifications

@MainActor
final class AppController: NSObject, ObservableObject {
    @Published var settings: BreakSettings
    @Published var stats: BreakStats
    @Published var activeEvent: BreakEvent?
    @Published var activeEndsAt: Date?
    @Published var nextEvent: BreakEvent?
    @Published var activeRoutine: BreakRoutine?
    @Published var smartDetection = SmartDetectionState()

    private let scheduler = BreakScheduler()
    private let settingsStore = SettingsStore()
    private let statsStore = StatsStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var activityStartedAt = Date()
    private var lastCompletedAt: Date?
    private var lastMicroCompletedAt: Date?
    private var lastMovementCompletedAt: Date?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var overlayWindows: [NSPanel] = []
    private var apiServer: LocalAPIServer?
    private var smartMonitor: SmartDetectionMonitor?
    private var wasIdle = false
    private var wasSmartAway = false
    private var lastIdleResetAt: Date?
    private var lastSmartResetAt: Date?
    private var lastHeadsUpStartsAt: Date?
    private var lastTickAt: Date?
    private var cancellables: Set<AnyCancellable> = []

    init(now: Date = Date()) {
        self.settings = settingsStore.load()
        self.stats = statsStore.load()
        self.activityStartedAt = now
        super.init()
    }

    func start() {
        configureStatusItem()
        requestNotificationPermissionIfNeeded()
        updateNextEvent()
        rebuildMenu()
        configureAPI()
        configureSmartDetection()
        if !settings.onboardingCompleted {
            openOnboarding()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        $settings
            .dropFirst()
            .sink { [weak self] settings in
                self?.settingsStore.save(settings)
                self?.applyLaunchAtLogin(settings.launchAtLogin)
                self?.configureAPI()
                self?.configureSmartDetection()
                self?.updateNextEvent()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        $stats
            .dropFirst()
            .sink { [weak self] stats in
                self?.statsStore.save(stats)
            }
            .store(in: &cancellables)
    }

    var remainingText: String {
        guard let date = nextEvent?.startsAt else { return "Paused" }
        return Self.formatRemaining(max(0, date.timeIntervalSinceNow))
    }

    var activeRemainingText: String {
        guard let activeEndsAt else { return "" }
        return Self.formatRemaining(max(0, activeEndsAt.timeIntervalSinceNow))
    }

    var activeTitle: String {
        switch activeEvent?.kind {
        case .micro:
            return "Look away"
        case .movement:
            return "Stand up"
        case nil:
            return "Reset"
        }
    }

    var activeSubtitle: String {
        activeRoutine?.subtitle ?? "Take a short reset."
    }

    func tick() {
        let now = Date()
        lastTickAt = now
        applyIdleResetIfNeeded(now: now)
        applySmartResetIfNeeded(now: now)

        if let activeEndsAt, now >= activeEndsAt {
            completeBreak()
            return
        }

        updateNextEvent(now: now)
        sendHeadsUpIfNeeded(now: now)
        if activeEvent == nil, nextEvent?.startsAt ?? .distantFuture <= now, currentMeetingDetection != nil {
            updateStatusTitle()
            return
        }
        if activeEvent == nil, let nextEvent, nextEvent.startsAt <= now {
            beginBreak(nextEvent)
        }

        updateStatusTitle()
    }

    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskReset"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: self))
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func openOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to DeskReset"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OnboardingView(controller: self))
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func finishOnboarding() {
        settings.onboardingCompleted = true
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func takeBreakNow(kind: BreakKind) {
        let duration = kind == .micro ? settings.microDuration : settings.movementDuration
        beginBreak(BreakEvent(kind: kind, startsAt: Date(), duration: duration))
    }

    func completeBreak() {
        let now = Date()
        if let event = activeEvent {
            stats.completedBreaks += 1
            stats.mindfulSeconds += Int(event.duration)
            if event.kind == .movement {
                stats.movementBreaks += 1
                lastMovementCompletedAt = now
            } else {
                lastMicroCompletedAt = now
            }
            stats.lastBreakAt = now
        }
        lastCompletedAt = now
        activityStartedAt = now
        activeEvent = nil
        activeEndsAt = nil
        activeRoutine = nil
        closeOverlay()
        updateNextEvent(now: now)
        rebuildMenu()
    }

    func skipBreak() {
        let now = Date()
        stats.skippedBreaks += 1
        lastCompletedAt = now
        if activeEvent?.kind == .movement {
            lastMovementCompletedAt = now
        } else if activeEvent?.kind == .micro {
            lastMicroCompletedAt = now
        }
        activeEvent = nil
        activeEndsAt = nil
        activeRoutine = nil
        closeOverlay()
        updateNextEvent()
        rebuildMenu()
    }

    func snooze(minutes: Int) {
        stats.snoozedBreaks += 1
        settings.pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        activeEvent = nil
        activeEndsAt = nil
        activeRoutine = nil
        closeOverlay()
        rebuildMenu()
    }

    func focus(minutes: Int) {
        settings.pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        activeEvent = nil
        activeEndsAt = nil
        activeRoutine = nil
        closeOverlay()
        rebuildMenu()
    }

    func clearPause() {
        settings.pausedUntil = nil
        updateNextEvent()
        rebuildMenu()
    }

    func resetStats() {
        stats = .empty
    }

    func apiResponse(for command: APICommand, body: Data?) -> APIHTTPResponse {
        switch command {
        case .status:
            return .ok(statusPayload())
        case .settings:
            return .ok(["ok": true, "settings": encodeObject(settings)])
        case .updateSettings:
            return updateSettingsFromAPI(body)
        case .startBreak(let kind):
            takeBreakNow(kind: kind)
            return .ok(statusPayload())
        case .completeBreak:
            completeBreak()
            return .ok(statusPayload())
        case .skipBreak:
            skipBreak()
            return .ok(statusPayload())
        case .snooze(let minutes):
            snooze(minutes: minutes)
            return .ok(statusPayload())
        case .focus(let minutes):
            focus(minutes: minutes)
            return .ok(statusPayload())
        case .resume:
            clearPause()
            return .ok(statusPayload())
        case .resetStats:
            resetStats()
            return .ok(statusPayload())
        case .openSettings:
            openSettings()
            return .ok(["ok": true])
        case .openOnboarding:
            openOnboarding()
            return .ok(["ok": true])
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<BreakSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { self.settings[keyPath: keyPath] = $0 }
        )
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "DeskReset")
            button.imagePosition = .imageLeading
            button.title = "DeskReset"
        }
        updateStatusTitle()
    }

    private func configureAPI() {
        if settings.apiEnabled {
            if apiServer == nil {
                apiServer = LocalAPIServer { [weak self] command, body in
                    self?.apiResponse(for: command, body: body) ?? APIHTTPResponse(status: 400, body: ["ok": false, "error": "app_unavailable"])
                }
            }
            do {
                try apiServer?.start(port: settings.apiPort)
            } catch {
                NSLog("DeskReset API failed to start: \(error)")
            }
        } else {
            apiServer?.stop()
        }
    }

    private func configureSmartDetection() {
        if settings.smartDetectionEnabled {
            if smartMonitor == nil {
                smartMonitor = SmartDetectionMonitor(state: smartDetection)
            }
            smartMonitor?.start()
        } else {
            smartMonitor?.stop()
        }
    }

    private func applyIdleResetIfNeeded(now: Date) {
        guard settings.idleResetEnabled else { return }
        if settings.smartDetectionEnabled, smartDetection.facePresent {
            wasIdle = false
            return
        }
        let threshold = TimeInterval(settings.idleResetMinutes * 60)
        let idle = currentIdleSeconds

        if idle >= threshold {
            wasIdle = true
            return
        }

        if wasIdle {
            wasIdle = false
            lastIdleResetAt = now
            activityStartedAt = now
            lastCompletedAt = now
            lastMicroCompletedAt = now
            lastMovementCompletedAt = now
            activeEvent = nil
            activeEndsAt = nil
            activeRoutine = nil
            closeOverlay()
            updateNextEvent(now: now)
            rebuildMenu()
        }
    }

    private func applySmartResetIfNeeded(now: Date) {
        guard settings.smartDetectionEnabled else { return }
        if smartDetection.awaySeconds >= TimeInterval(settings.smartDetectionAwaySeconds) {
            wasSmartAway = true
            return
        }

        if wasSmartAway, smartDetection.facePresent {
            wasSmartAway = false
            lastSmartResetAt = now
            activityStartedAt = now
            lastCompletedAt = now
            lastMicroCompletedAt = now
            lastMovementCompletedAt = now
            activeEvent = nil
            activeEndsAt = nil
            activeRoutine = nil
            closeOverlay()
            updateNextEvent(now: now)
            rebuildMenu()
        }
    }

    private var currentIdleSeconds: TimeInterval {
        UserIdleClock.secondsSinceLastInput()
    }

    private var activeTimePauseThreshold: TimeInterval {
        TimeInterval(settings.idleResetMinutes * 60)
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        if activeEvent != nil {
            button.title = activeRemainingText
        } else if currentMeetingDetection != nil, nextEvent?.startsAt ?? .distantFuture <= Date() {
            button.title = "Meeting"
        } else {
            button.title = remainingText
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let state = NSMenuItem(title: menuHeadline(), action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        menu.addItem(.separator())

        addMenuItem("Take eye break now", action: #selector(takeMicroBreak), to: menu)
        addMenuItem("Take movement break now", action: #selector(takeMovementBreak), to: menu)
        menu.addItem(.separator())

        let focusMenu = NSMenu()
        addMenuItem("30 minutes", action: #selector(focus30), to: focusMenu)
        addMenuItem("60 minutes", action: #selector(focus60), to: focusMenu)
        addMenuItem("90 minutes", action: #selector(focus90), to: focusMenu)
        let focusItem = NSMenuItem(title: "Deep work", action: nil, keyEquivalent: "")
        focusItem.submenu = focusMenu
        menu.addItem(focusItem)

        if settings.pausedUntil != nil {
            addMenuItem("Resume reminders", action: #selector(resumeReminders), to: menu)
        }

        menu.addItem(.separator())
        addMenuItem("Settings...", action: #selector(openSettingsAction), to: menu)
        addMenuItem("Welcome guide...", action: #selector(openOnboardingAction), to: menu)
        addMenuItem("Quit", action: #selector(quit), to: menu)

        statusItem.menu = menu
    }

    private func menuHeadline() -> String {
        if activeEvent != nil {
            return "\(activeTitle): \(activeRemainingText)"
        }
        if let pausedUntil = settings.pausedUntil, pausedUntil > Date() {
            return "Paused until \(Self.shortTime(pausedUntil))"
        }
        if let meeting = currentMeetingDetection, nextEvent?.startsAt ?? .distantFuture <= Date() {
            return "Break deferred during \(meeting.appName)"
        }
        if let event = nextEvent {
            return "Next \(event.kind.label.lowercased()) in \(remainingText)"
        }
        return "Reminders are off"
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func updateNextEvent(now: Date = Date()) {
        nextEvent = scheduler.nextEvent(
            now: now,
            activityStartedAt: activityStartedAt,
            lastCompletedAt: lastCompletedAt,
            settings: settings,
            lastMicroCompletedAt: lastMicroCompletedAt,
            lastMovementCompletedAt: lastMovementCompletedAt
        )
    }

    private func beginBreak(_ event: BreakEvent) {
        lastHeadsUpStartsAt = nil
        activeEvent = event
        activeEndsAt = Date().addingTimeInterval(event.duration)
        activeRoutine = BreakRoutine.recommended(for: event.kind, completedCount: stats.completedBreaks)
        if settings.notificationsEnabled {
            sendNotification(for: event)
        }
        if settings.overlayEnabled {
            showOverlay()
        }
        rebuildMenu()
    }

    private func sendHeadsUpIfNeeded(now: Date) {
        guard
            settings.headsUpEnabled,
            settings.notificationsEnabled,
            activeEvent == nil,
            let event = nextEvent
        else {
            return
        }

        let secondsUntilBreak = event.startsAt.timeIntervalSince(now)
        guard secondsUntilBreak > 0, secondsUntilBreak <= TimeInterval(settings.headsUpSeconds) else {
            return
        }
        guard lastHeadsUpStartsAt != event.startsAt else {
            return
        }

        lastHeadsUpStartsAt = event.startsAt
        sendHeadsUpNotification(for: event, secondsUntilBreak: secondsUntilBreak)
    }

    private func showOverlay() {
        closeOverlay()

        let screens = settings.showOverlayOnAllDisplays ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        for screen in screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = settings.strictMode ? .screenSaver : .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: BreakOverlayView(controller: self))
            panel.orderFrontRegardless()
            overlayWindows.append(panel)
        }
    }

    private func closeOverlay() {
        overlayWindows.forEach { $0.close() }
        overlayWindows = []
    }

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(for event: BreakEvent) {
        let content = UNMutableNotificationContent()
        let routine = BreakRoutine.recommended(for: event.kind, completedCount: stats.completedBreaks)
        content.title = routine.title
        content.body = routine.subtitle
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "deskreset.break.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendHeadsUpNotification(for event: BreakEvent, secondsUntilBreak: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "\(event.kind.label) soon"
        content.body = "Starts in \(Self.formatRemaining(secondsUntilBreak)). Wrap up your thought."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "deskreset.heads-up.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func statusPayload() -> [String: Any] {
        [
            "ok": true,
            "active": activeEvent.map { eventPayload($0) } as Any,
            "activeEndsAt": activeEndsAt?.iso8601String as Any,
            "next": nextEvent.map { eventPayload($0) } as Any,
            "nextInSeconds": nextEvent.map { max(0, Int($0.startsAt.timeIntervalSinceNow.rounded())) } as Any,
            "pausedUntil": settings.pausedUntil?.iso8601String as Any,
            "idleSeconds": Int(currentIdleSeconds.rounded()),
            "activeTimePaused": CountdownPolicy.shouldPauseVisibleCountdown(
                idleSeconds: currentIdleSeconds,
                naturalBreakThreshold: activeTimePauseThreshold,
                facePresent: smartDetection.facePresent
            ),
            "lastIdleResetAt": lastIdleResetAt?.iso8601String as Any,
            "meeting": meetingPayload(),
            "smartDetection": [
                "enabled": settings.smartDetectionEnabled,
                "status": smartDetection.status.rawValue,
                "facePresent": smartDetection.facePresent,
                "awaySeconds": Int(smartDetection.awaySeconds.rounded()),
                "lastFaceSeenAt": smartDetection.lastFaceSeenAt?.iso8601String as Any,
                "lastResetAt": lastSmartResetAt?.iso8601String as Any,
                "error": smartDetection.lastError as Any
            ],
            "stats": encodeObject(stats),
            "api": [
                "enabled": settings.apiEnabled,
                "port": settings.apiPort
            ]
        ]
    }

    private func meetingPayload() -> [String: Any] {
        let detection = currentMeetingDetection
        return [
                "enabled": settings.meetingDetectionEnabled,
                "active": detection != nil,
                "app": detection?.appName as Any,
                "reason": detection?.reason.rawValue as Any,
                "detail": detection?.detail as Any
        ]
    }

    private func eventPayload(_ event: BreakEvent) -> [String: Any] {
        [
            "kind": event.kind.rawValue,
            "startsAt": event.startsAt.iso8601String,
            "durationSeconds": Int(event.duration)
        ]
    }

    private func updateSettingsFromAPI(_ body: Data?) -> APIHTTPResponse {
        guard
            let body,
            let object = try? JSONSerialization.jsonObject(with: body),
            let patch = object as? [String: Any]
        else {
            return APIHTTPResponse(status: 400, body: ["ok": false, "error": "invalid_json"])
        }

        if let value = patch["microEnabled"] as? Bool { settings.microEnabled = value }
        if let value = patch["movementEnabled"] as? Bool { settings.movementEnabled = value }
        if let value = patch["notificationsEnabled"] as? Bool { settings.notificationsEnabled = value }
        if let value = patch["overlayEnabled"] as? Bool { settings.overlayEnabled = value }
        if let value = patch["showOverlayOnAllDisplays"] as? Bool { settings.showOverlayOnAllDisplays = value }
        if let value = patch["strictMode"] as? Bool { settings.strictMode = value }
        if let value = patch["apiEnabled"] as? Bool { settings.apiEnabled = value }
        if let value = patch["apiPort"] as? Int, value > 1024, value < 65535 { settings.apiPort = value }
        if let value = patch["idleResetEnabled"] as? Bool { settings.idleResetEnabled = value }
        if let value = patch["idleResetMinutes"] as? Int, value > 0, value <= 120 { settings.idleResetMinutes = value }
        if let value = patch["headsUpEnabled"] as? Bool { settings.headsUpEnabled = value }
        if let value = patch["headsUpSeconds"] as? Int, value >= 10, value <= 600 { settings.headsUpSeconds = value }
        if let value = patch["meetingDetectionEnabled"] as? Bool { settings.meetingDetectionEnabled = value }
        if let value = patch["smartDetectionEnabled"] as? Bool { settings.smartDetectionEnabled = value }
        if let value = patch["smartDetectionAwaySeconds"] as? Int, value >= 5, value <= 300 { settings.smartDetectionAwaySeconds = value }
        if let value = patch["snoozeMinutes"] as? Int, value > 0, value <= 60 { settings.snoozeMinutes = value }
        if let value = patch["microIntervalMinutes"] as? Double, value >= 1 { settings.microInterval = value * 60 }
        if let value = patch["microDurationSeconds"] as? Double, value >= 1 { settings.microDuration = value }
        if let value = patch["movementIntervalMinutes"] as? Double, value >= 1 { settings.movementInterval = value * 60 }
        if let value = patch["movementDurationMinutes"] as? Double, value >= 1 { settings.movementDuration = value * 60 }

        return .ok(["ok": true, "settings": encodeObject(settings)])
    }

    private func encodeObject<T: Encodable>(_ value: T) -> Any {
        guard
            let data = try? JSONEncoder.api.encode(value),
            let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return [:]
        }
        return object
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login update failed: \(error)")
        }
    }

    private var currentMeetingDetection: MeetingDetection? {
        guard settings.meetingDetectionEnabled else { return nil }
        return MeetingDetector.detect(from: meetingSignals())
    }

    private func meetingSignals() -> [MeetingSignal] {
        var signals: [MeetingSignal] = []

        if let app = NSWorkspace.shared.frontmostApplication {
            let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            signals.append(MeetingSignal(
                appName: appName,
                bundleIdentifier: app.bundleIdentifier,
                windowTitle: nil
            ))
        }

        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return signals
        }

        for window in windows {
            guard let owner = window[kCGWindowOwnerName as String] as? String, !owner.isEmpty else {
                continue
            }
            let title = window[kCGWindowName as String] as? String
            guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            signals.append(MeetingSignal(
                appName: owner,
                bundleIdentifier: nil,
                windowTitle: title
            ))
        }

        return signals
    }

    @objc private func openSettingsAction() { openSettings() }
    @objc private func openOnboardingAction() { openOnboarding() }
    @objc private func takeMicroBreak() { takeBreakNow(kind: .micro) }
    @objc private func takeMovementBreak() { takeBreakNow(kind: .movement) }
    @objc private func focus30() { focus(minutes: 30) }
    @objc private func focus60() { focus(minutes: 60) }
    @objc private func focus90() { focus(minutes: 90) }
    @objc private func resumeReminders() { clearPause() }
    @objc private func quit() { NSApp.terminate(nil) }

    static func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return minutes > 0 ? "\(minutes)m \(remainder)s" : "\(remainder)s"
    }

    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension APIHTTPResponse {
    static func ok(_ body: [String: Any]) -> APIHTTPResponse {
        APIHTTPResponse(status: 200, body: body)
    }
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

private extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension BreakKind {
    var label: String {
        switch self {
        case .micro: return "Eye break"
        case .movement: return "Movement break"
        }
    }
}

struct BreakStats: Codable, Equatable {
    var completedBreaks: Int
    var movementBreaks: Int
    var skippedBreaks: Int
    var snoozedBreaks: Int
    var mindfulSeconds: Int
    var lastBreakAt: Date?

    static let empty = BreakStats(
        completedBreaks: 0,
        movementBreaks: 0,
        skippedBreaks: 0,
        snoozedBreaks: 0,
        mindfulSeconds: 0,
        lastBreakAt: nil
    )
}

private struct SettingsStore {
    private let key = "deskreset.settings.v1"

    func load() -> BreakSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(BreakSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    func save(_ settings: BreakSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct StatsStore {
    private let key = "deskreset.stats.v1"

    func load() -> BreakStats {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let stats = try? JSONDecoder().decode(BreakStats.self, from: data)
        else {
            return .empty
        }
        return stats
    }

    func save(_ stats: BreakStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
