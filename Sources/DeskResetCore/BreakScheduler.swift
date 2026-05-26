import Foundation

public enum BreakKind: String, Codable, Sendable {
    case micro
    case movement
}

public struct TimeOfDay: Codable, Equatable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

public struct BreakSettings: Codable, Equatable, Sendable {
    public var microEnabled: Bool
    public var microInterval: TimeInterval
    public var microDuration: TimeInterval
    public var movementEnabled: Bool
    public var movementInterval: TimeInterval
    public var movementDuration: TimeInterval
    public var notificationsEnabled: Bool
    public var overlayEnabled: Bool
    public var apiEnabled: Bool
    public var apiPort: Int
    public var idleResetEnabled: Bool
    public var idleResetMinutes: Int
    public var headsUpEnabled: Bool
    public var headsUpSeconds: Int
    public var meetingDetectionEnabled: Bool
    public var smartDetectionEnabled: Bool
    public var smartDetectionAwaySeconds: Int
    public var showOverlayOnAllDisplays: Bool
    public var strictMode: Bool
    public var snoozeMinutes: Int
    public var launchAtLogin: Bool
    public var onboardingCompleted: Bool
    public var quietHoursEnabled: Bool
    public var quietHoursStart: TimeOfDay
    public var quietHoursEnd: TimeOfDay
    public var pausedUntil: Date?

    public static let defaults = BreakSettings(
        microEnabled: true,
        microInterval: 20 * 60,
        microDuration: 20,
        movementEnabled: true,
        movementInterval: 60 * 60,
        movementDuration: 5 * 60,
        notificationsEnabled: true,
        overlayEnabled: true,
        apiEnabled: true,
        apiPort: 17777,
        idleResetEnabled: true,
        idleResetMinutes: 5,
        headsUpEnabled: true,
        headsUpSeconds: 60,
        meetingDetectionEnabled: true,
        smartDetectionEnabled: false,
        smartDetectionAwaySeconds: 20,
        showOverlayOnAllDisplays: true,
        strictMode: false,
        snoozeMinutes: 5,
        launchAtLogin: false,
        onboardingCompleted: false,
        quietHoursEnabled: false,
        quietHoursStart: TimeOfDay(hour: 21, minute: 30),
        quietHoursEnd: TimeOfDay(hour: 7, minute: 0),
        pausedUntil: nil
    )

    public init(
        microEnabled: Bool,
        microInterval: TimeInterval,
        microDuration: TimeInterval,
        movementEnabled: Bool,
        movementInterval: TimeInterval,
        movementDuration: TimeInterval,
        notificationsEnabled: Bool,
        overlayEnabled: Bool,
        apiEnabled: Bool,
        apiPort: Int,
        idleResetEnabled: Bool,
        idleResetMinutes: Int,
        headsUpEnabled: Bool,
        headsUpSeconds: Int,
        meetingDetectionEnabled: Bool,
        smartDetectionEnabled: Bool,
        smartDetectionAwaySeconds: Int,
        showOverlayOnAllDisplays: Bool,
        strictMode: Bool,
        snoozeMinutes: Int,
        launchAtLogin: Bool,
        onboardingCompleted: Bool,
        quietHoursEnabled: Bool,
        quietHoursStart: TimeOfDay,
        quietHoursEnd: TimeOfDay,
        pausedUntil: Date?
    ) {
        self.microEnabled = microEnabled
        self.microInterval = microInterval
        self.microDuration = microDuration
        self.movementEnabled = movementEnabled
        self.movementInterval = movementInterval
        self.movementDuration = movementDuration
        self.notificationsEnabled = notificationsEnabled
        self.overlayEnabled = overlayEnabled
        self.apiEnabled = apiEnabled
        self.apiPort = apiPort
        self.idleResetEnabled = idleResetEnabled
        self.idleResetMinutes = idleResetMinutes
        self.headsUpEnabled = headsUpEnabled
        self.headsUpSeconds = headsUpSeconds
        self.meetingDetectionEnabled = meetingDetectionEnabled
        self.smartDetectionEnabled = smartDetectionEnabled
        self.smartDetectionAwaySeconds = smartDetectionAwaySeconds
        self.showOverlayOnAllDisplays = showOverlayOnAllDisplays
        self.strictMode = strictMode
        self.snoozeMinutes = snoozeMinutes
        self.launchAtLogin = launchAtLogin
        self.onboardingCompleted = onboardingCompleted
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.pausedUntil = pausedUntil
    }

    enum CodingKeys: String, CodingKey {
        case microEnabled
        case microInterval
        case microDuration
        case movementEnabled
        case movementInterval
        case movementDuration
        case notificationsEnabled
        case overlayEnabled
        case apiEnabled
        case apiPort
        case idleResetEnabled
        case idleResetMinutes
        case headsUpEnabled
        case headsUpSeconds
        case meetingDetectionEnabled
        case smartDetectionEnabled
        case smartDetectionAwaySeconds
        case showOverlayOnAllDisplays
        case strictMode
        case snoozeMinutes
        case launchAtLogin
        case onboardingCompleted
        case quietHoursEnabled
        case quietHoursStart
        case quietHoursEnd
        case pausedUntil
    }

    public init(from decoder: Decoder) throws {
        let defaults = BreakSettings.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.microEnabled = try container.decodeIfPresent(Bool.self, forKey: .microEnabled) ?? defaults.microEnabled
        self.microInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .microInterval) ?? defaults.microInterval
        self.microDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .microDuration) ?? defaults.microDuration
        self.movementEnabled = try container.decodeIfPresent(Bool.self, forKey: .movementEnabled) ?? defaults.movementEnabled
        self.movementInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .movementInterval) ?? defaults.movementInterval
        self.movementDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .movementDuration) ?? defaults.movementDuration
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
        self.overlayEnabled = try container.decodeIfPresent(Bool.self, forKey: .overlayEnabled) ?? defaults.overlayEnabled
        self.apiEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiEnabled) ?? defaults.apiEnabled
        self.apiPort = try container.decodeIfPresent(Int.self, forKey: .apiPort) ?? defaults.apiPort
        self.idleResetEnabled = try container.decodeIfPresent(Bool.self, forKey: .idleResetEnabled) ?? defaults.idleResetEnabled
        self.idleResetMinutes = try container.decodeIfPresent(Int.self, forKey: .idleResetMinutes) ?? defaults.idleResetMinutes
        self.headsUpEnabled = try container.decodeIfPresent(Bool.self, forKey: .headsUpEnabled) ?? defaults.headsUpEnabled
        self.headsUpSeconds = try container.decodeIfPresent(Int.self, forKey: .headsUpSeconds) ?? defaults.headsUpSeconds
        self.meetingDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .meetingDetectionEnabled) ?? defaults.meetingDetectionEnabled
        self.smartDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartDetectionEnabled) ?? defaults.smartDetectionEnabled
        self.smartDetectionAwaySeconds = try container.decodeIfPresent(Int.self, forKey: .smartDetectionAwaySeconds) ?? defaults.smartDetectionAwaySeconds
        self.showOverlayOnAllDisplays = try container.decodeIfPresent(Bool.self, forKey: .showOverlayOnAllDisplays) ?? defaults.showOverlayOnAllDisplays
        self.strictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? defaults.strictMode
        self.snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? defaults.snoozeMinutes
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        self.onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? defaults.onboardingCompleted
        self.quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? defaults.quietHoursEnabled
        self.quietHoursStart = try container.decodeIfPresent(TimeOfDay.self, forKey: .quietHoursStart) ?? defaults.quietHoursStart
        self.quietHoursEnd = try container.decodeIfPresent(TimeOfDay.self, forKey: .quietHoursEnd) ?? defaults.quietHoursEnd
        self.pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
    }
}

public struct BreakEvent: Equatable, Sendable {
    public var kind: BreakKind
    public var startsAt: Date
    public var duration: TimeInterval

    public init(kind: BreakKind, startsAt: Date, duration: TimeInterval) {
        self.kind = kind
        self.startsAt = startsAt
        self.duration = duration
    }
}

public struct ActiveTimeAdjustment: Sendable {
    public static func shiftedAnchors(
        idleSeconds: TimeInterval,
        elapsedSeconds: TimeInterval,
        idleGraceSeconds: TimeInterval = 30,
        activityStartedAt: Date,
        lastCompletedAt: Date?
    ) -> (activityStartedAt: Date, lastCompletedAt: Date?) {
        guard idleSeconds > idleGraceSeconds, elapsedSeconds > 0 else {
            return (activityStartedAt, lastCompletedAt)
        }
        return (
            activityStartedAt.addingTimeInterval(elapsedSeconds),
            lastCompletedAt?.addingTimeInterval(elapsedSeconds)
        )
    }
}

public struct BreakScheduler: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func nextEvent(
        now: Date,
        activityStartedAt: Date,
        lastCompletedAt: Date?,
        settings: BreakSettings,
        lastMicroCompletedAt: Date? = nil,
        lastMovementCompletedAt: Date? = nil
    ) -> BreakEvent {
        let microAnchor = lastMicroCompletedAt ?? lastCompletedAt ?? activityStartedAt
        let movementAnchor = lastMovementCompletedAt ?? activityStartedAt
        var candidates: [BreakEvent] = []
        if settings.microEnabled {
            candidates.append(BreakEvent(
                kind: .micro,
                startsAt: microAnchor.addingTimeInterval(settings.microInterval),
                duration: settings.microDuration
            ))
        }
        if settings.movementEnabled {
            candidates.append(BreakEvent(
                kind: .movement,
                startsAt: movementAnchor.addingTimeInterval(settings.movementInterval),
                duration: settings.movementDuration
            ))
        }

        let selected = selectEvent(from: candidates, now: now, settings: settings)

        var startsAt = selected.startsAt
        if let pausedUntil = settings.pausedUntil, pausedUntil > startsAt {
            startsAt = pausedUntil
        }
        if settings.quietHoursEnabled, let quietEnd = quietHoursEnd(afterOrContaining: startsAt, settings: settings) {
            startsAt = quietEnd
        }

        return BreakEvent(kind: selected.kind, startsAt: startsAt, duration: selected.duration)
    }

    private func selectEvent(from candidates: [BreakEvent], now: Date, settings: BreakSettings) -> BreakEvent {
        if candidates.isEmpty {
            return BreakEvent(kind: .micro, startsAt: .distantFuture, duration: settings.microDuration)
        }

        let due = candidates.filter { now >= $0.startsAt }
        if let movement = due.first(where: { $0.kind == .movement }) {
            return BreakEvent(kind: movement.kind, startsAt: now, duration: movement.duration)
        }
        if let micro = due.first(where: { $0.kind == .micro }) {
            return BreakEvent(kind: micro.kind, startsAt: now, duration: micro.duration)
        }

        return candidates.sorted { left, right in
            if left.startsAt == right.startsAt {
                return left.kind == .movement
            }
            return left.startsAt < right.startsAt
        }[0]
    }

    private func quietHoursEnd(afterOrContaining date: Date, settings: BreakSettings) -> Date? {
        let start = settings.quietHoursStart
        let end = settings.quietHoursEnd
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard
            let startToday = calendar.date(
                bySettingHour: start.hour,
                minute: start.minute,
                second: 0,
                of: calendar.date(from: components) ?? date
            ),
            let endToday = calendar.date(
                bySettingHour: end.hour,
                minute: end.minute,
                second: 0,
                of: calendar.date(from: components) ?? date
            )
        else {
            return nil
        }

        if startToday <= endToday {
            return (date >= startToday && date < endToday) ? endToday : nil
        }

        if date >= startToday {
            return calendar.date(byAdding: .day, value: 1, to: endToday)
        }
        if date < endToday {
            return endToday
        }
        return nil
    }
}

public struct BreakRoutine: Codable, Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var steps: [String]

    public init(title: String, subtitle: String, steps: [String]) {
        self.title = title
        self.subtitle = subtitle
        self.steps = steps
    }

    public static func recommended(for kind: BreakKind, completedCount: Int) -> BreakRoutine {
        let routines = kind == .micro ? eyeRoutines : movementRoutines
        return routines[abs(completedCount) % routines.count]
    }

    public static let eyeRoutines: [BreakRoutine] = [
        BreakRoutine(
            title: "20-20 reset",
            subtitle: "Let your focus relax away from the display.",
            steps: [
                "Look at something at least 20 feet away.",
                "Blink slowly five times.",
                "Drop your shoulders and unclench your jaw."
            ]
        ),
        BreakRoutine(
            title: "Soft focus",
            subtitle: "Reduce eye strain without leaving flow.",
            steps: [
                "Look out a window or across the room.",
                "Trace a slow horizontal line with your eyes.",
                "Return only when your eyes feel relaxed."
            ]
        )
    ]

    public static let movementRoutines: [BreakRoutine] = [
        BreakRoutine(
            title: "Stand and walk",
            subtitle: "Get circulation back before the next focus block.",
            steps: [
                "Stand fully away from the keyboard.",
                "Walk for one to two minutes.",
                "Roll your shoulders and reset your seat height."
            ]
        ),
        BreakRoutine(
            title: "Posture reset",
            subtitle: "Undo the typing position.",
            steps: [
                "Stand tall with both feet planted.",
                "Open your chest and gently extend your wrists.",
                "Take five slow breaths before sitting down."
            ]
        )
    ]
}
