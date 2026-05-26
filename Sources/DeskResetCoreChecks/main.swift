import Foundation
import DeskResetCore

let calendar = Calendar(identifier: .gregorian)

try check("default settings schedule a micro break after twenty minutes") {
    let scheduler = BreakScheduler(calendar: calendar)
    let start = try unwrap(date("2026-05-26 09:00"))
    let event = scheduler.nextEvent(
        now: start,
        activityStartedAt: start,
        lastCompletedAt: nil,
        settings: .defaults
    )

    try expect(event.kind == .micro, "expected micro, got \(event.kind)")
    try expect(event.startsAt == start.addingTimeInterval(20 * 60), "wrong start \(event.startsAt)")
    try expect(event.duration == 20, "wrong duration \(event.duration)")
}

try check("movement breaks win when both micro and movement are due") {
    let scheduler = BreakScheduler(calendar: calendar)
    let start = try unwrap(date("2026-05-26 09:00"))
    let now = start.addingTimeInterval(60 * 60)
    let event = scheduler.nextEvent(
        now: now,
        activityStartedAt: start,
        lastCompletedAt: nil,
        settings: .defaults
    )

    try expect(event.kind == .movement, "expected movement, got \(event.kind)")
    try expect(event.startsAt == now, "wrong start \(event.startsAt)")
    try expect(event.duration == 5 * 60, "wrong duration \(event.duration)")
}

try check("movement cadence is not postponed by completed eye breaks") {
    let scheduler = BreakScheduler(calendar: calendar)
    let start = try unwrap(date("2026-05-26 09:00"))
    let microCompleted = try unwrap(date("2026-05-26 09:40"))
    let event = scheduler.nextEvent(
        now: microCompleted,
        activityStartedAt: start,
        lastCompletedAt: microCompleted,
        settings: .defaults,
        lastMicroCompletedAt: microCompleted,
        lastMovementCompletedAt: nil
    )

    let due = try unwrap(date("2026-05-26 10:00"))
    try expect(event.kind == .movement, "expected movement after several eye breaks, got \(event.kind)")
    try expect(event.startsAt == due, "wrong movement due time \(event.startsAt)")
}

try check("quiet hours defer breaks until the quiet window ends") {
    let scheduler = BreakScheduler(calendar: calendar)
    let now = try unwrap(date("2026-05-26 22:30"))
    var settings = BreakSettings.defaults
    settings.quietHoursEnabled = true
    settings.quietHoursStart = TimeOfDay(hour: 21, minute: 30)
    settings.quietHoursEnd = TimeOfDay(hour: 7, minute: 0)

    let event = scheduler.nextEvent(
        now: now,
        activityStartedAt: now.addingTimeInterval(-3 * 60 * 60),
        lastCompletedAt: nil,
        settings: settings
    )

    let quietEnd = try unwrap(date("2026-05-27 07:00"))
    try expect(event.kind == .movement, "expected movement, got \(event.kind)")
    try expect(event.startsAt == quietEnd, "wrong quiet-hour resume \(event.startsAt)")
}

try check("paused schedules resume after focus ends") {
    let scheduler = BreakScheduler(calendar: calendar)
    let now = try unwrap(date("2026-05-26 11:00"))
    var settings = BreakSettings.defaults
    settings.pausedUntil = now.addingTimeInterval(45 * 60)

    let event = scheduler.nextEvent(
        now: now,
        activityStartedAt: now.addingTimeInterval(-2 * 60 * 60),
        lastCompletedAt: nil,
        settings: settings
    )

    try expect(event.startsAt == settings.pausedUntil, "expected pause until \(String(describing: settings.pausedUntil)), got \(event.startsAt)")
}

try check("completing a break resets the next interval from completion") {
    let scheduler = BreakScheduler(calendar: calendar)
    let start = try unwrap(date("2026-05-26 09:00"))
    let completed = try unwrap(date("2026-05-26 09:25"))

    let event = scheduler.nextEvent(
        now: completed,
        activityStartedAt: start,
        lastCompletedAt: completed,
        settings: .defaults
    )

    try expect(event.kind == .micro, "expected micro, got \(event.kind)")
    try expect(event.startsAt == completed.addingTimeInterval(20 * 60), "wrong reset start \(event.startsAt)")
}

try check("disabled micro breaks fall through to movement breaks") {
    let scheduler = BreakScheduler(calendar: calendar)
    let start = try unwrap(date("2026-05-26 09:00"))
    var settings = BreakSettings.defaults
    settings.microEnabled = false

    let event = scheduler.nextEvent(
        now: start,
        activityStartedAt: start,
        lastCompletedAt: nil,
        settings: settings
    )

    try expect(event.kind == .movement, "expected movement, got \(event.kind)")
    try expect(event.startsAt == start.addingTimeInterval(60 * 60), "wrong movement start \(event.startsAt)")
}

try check("active time adjustment pauses anchors while the computer is idle") {
    let start = try unwrap(date("2026-05-26 09:00"))
    let completed = try unwrap(date("2026-05-26 09:20"))
    let shifted = ActiveTimeAdjustment.shiftedAnchors(
        idleSeconds: 45,
        elapsedSeconds: 10,
        activityStartedAt: start,
        lastCompletedAt: completed
    )

    try expect(shifted.activityStartedAt == start.addingTimeInterval(10), "activity anchor should shift by idle elapsed time")
    try expect(shifted.lastCompletedAt == completed.addingTimeInterval(10), "completion anchor should shift by idle elapsed time")
}

try check("active time adjustment ignores brief idle moments") {
    let start = try unwrap(date("2026-05-26 09:00"))
    let shifted = ActiveTimeAdjustment.shiftedAnchors(
        idleSeconds: 20,
        elapsedSeconds: 10,
        activityStartedAt: start,
        lastCompletedAt: nil
    )

    try expect(shifted.activityStartedAt == start, "brief idle should not move activity anchor")
    try expect(shifted.lastCompletedAt == nil, "brief idle should keep nil completion anchor")
}

try check("meeting detector recognizes dedicated video call apps") {
    let signal = MeetingSignal(
        appName: "zoom.us",
        bundleIdentifier: "us.zoom.xos",
        windowTitle: "Andrew's Zoom Meeting"
    )
    let detection = MeetingDetector.detect(from: [signal])

    try expect(detection?.appName == "zoom.us", "expected Zoom to be detected")
    try expect(detection?.reason == .dedicatedCallApp, "expected dedicated app reason")
}

try check("meeting detector recognizes browser-based meetings") {
    let signal = MeetingSignal(
        appName: "Google Chrome",
        bundleIdentifier: "com.google.Chrome",
        windowTitle: "Daily DeskReset - Google Meet"
    )
    let detection = MeetingDetector.detect(from: [signal])

    try expect(detection?.appName == "Google Chrome", "expected browser meeting to be detected")
    try expect(detection?.reason == .meetingWindowTitle, "expected window title reason")
}

try check("meeting detector recognizes Slack huddles without false positive on idle chat") {
    let idleSlack = MeetingSignal(
        appName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap",
        windowTitle: "Fleet AI"
    )
    let huddle = MeetingSignal(
        appName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap",
        windowTitle: "Huddle - Core Platform"
    )

    try expect(MeetingDetector.detect(from: [idleSlack]) == nil, "idle Slack should not count as a meeting")
    try expect(MeetingDetector.detect(from: [huddle])?.reason == .meetingWindowTitle, "Slack huddle should count")
}

try check("legacy settings decode with new preference defaults") {
    let legacyJSON = """
    {
      "microEnabled": true,
      "microInterval": 1200,
      "microDuration": 20,
      "movementEnabled": true,
      "movementInterval": 3600,
      "movementDuration": 300,
      "notificationsEnabled": true,
      "overlayEnabled": true,
      "launchAtLogin": false,
      "quietHoursEnabled": false,
      "quietHoursStart": { "hour": 21, "minute": 30 },
      "quietHoursEnd": { "hour": 7, "minute": 0 }
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(BreakSettings.self, from: legacyJSON)

    try expect(settings.showOverlayOnAllDisplays == true, "expected all-display overlay default")
    try expect(settings.strictMode == false, "expected strict mode to default off")
    try expect(settings.snoozeMinutes == 5, "expected five-minute snooze default")
    try expect(settings.onboardingCompleted == false, "expected onboarding to default incomplete")
    try expect(settings.idleResetEnabled == true, "expected idle reset to default on")
    try expect(settings.idleResetMinutes == 5, "expected five-minute idle reset default")
    try expect(settings.smartDetectionEnabled == false, "expected smart detection to default off")
    try expect(settings.smartDetectionAwaySeconds == 20, "expected smart detection away threshold default")
    try expect(settings.headsUpEnabled == true, "expected heads-up warnings to default on")
    try expect(settings.headsUpSeconds == 60, "expected one-minute heads-up default")
    try expect(settings.meetingDetectionEnabled == true, "expected meeting detection to default on")
}

try check("routine library provides concrete eye and movement guidance") {
    let eye = BreakRoutine.recommended(for: .micro, completedCount: 0)
    let movement = BreakRoutine.recommended(for: .movement, completedCount: 1)

    try expect(eye.title == "20-20 reset", "unexpected eye routine \(eye.title)")
    try expect(eye.steps.count >= 3, "eye routine needs actionable steps")
    try expect(movement.steps.contains(where: { $0.localizedCaseInsensitiveContains("walk") || $0.localizedCaseInsensitiveContains("stand") }), "movement routine should prompt physical movement")
}

try check("API router maps HTTP routes to app commands") {
    try expect(APIRouter.command(method: "GET", path: "/v1/status") == .status, "status route failed")
    try expect(APIRouter.command(method: "GET", path: "/v1/settings") == .settings, "settings route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/breaks/start/micro") == .startBreak(.micro), "micro route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/breaks/start/movement") == .startBreak(.movement), "movement route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/breaks/snooze?minutes=12") == .snooze(minutes: 12), "snooze route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/focus?minutes=90") == .focus(minutes: 90), "focus route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/reminders/resume") == .resume, "resume route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/stats/reset") == .resetStats, "stats reset route failed")
    try expect(APIRouter.command(method: "POST", path: "/v1/system/lock-screen") == nil, "lock screen route should stay out of the clean personal app")
}

try check("API router rejects unknown or invalid routes") {
    try expect(APIRouter.command(method: "POST", path: "/v1/breaks/start/coffee") == nil, "invalid break kind should fail")
    try expect(APIRouter.command(method: "GET", path: "/v1/breaks/start/micro") == nil, "wrong method should fail")
    try expect(APIRouter.command(method: "POST", path: "/v1/focus?minutes=abc") == nil, "invalid query should fail")
}

print("All DeskResetCore checks passed")

func date(_ text: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: text)
}

func check(_ name: String, _ body: () throws -> Void) throws {
    do {
        try body()
        print("PASS \(name)")
    } catch {
        fputs("FAIL \(name): \(error)\n", stderr)
        throw error
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure(message)
    }
}

func unwrap<T>(_ value: T?) throws -> T {
    if let value {
        return value
    }
    throw CheckFailure("unexpected nil")
}

struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
