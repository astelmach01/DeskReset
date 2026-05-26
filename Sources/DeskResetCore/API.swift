import Foundation

public enum APICommand: Equatable, Sendable {
    case status
    case settings
    case updateSettings
    case startBreak(BreakKind)
    case completeBreak
    case skipBreak
    case snooze(minutes: Int)
    case focus(minutes: Int)
    case resume
    case resetStats
    case openSettings
    case openOnboarding
}

public enum APIRouter {
    public static func command(method: String, path: String) -> APICommand? {
        let upperMethod = method.uppercased()
        guard let components = URLComponents(string: "http://deskreset.local\(path)") else {
            return nil
        }

        let route = components.path
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        switch (upperMethod, route) {
        case ("GET", "/v1/status"):
            return .status
        case ("GET", "/v1/settings"):
            return .settings
        case ("PATCH", "/v1/settings"), ("PUT", "/v1/settings"):
            return .updateSettings
        case ("POST", "/v1/breaks/start/micro"):
            return .startBreak(.micro)
        case ("POST", "/v1/breaks/start/movement"):
            return .startBreak(.movement)
        case ("POST", "/v1/breaks/complete"):
            return .completeBreak
        case ("POST", "/v1/breaks/skip"):
            return .skipBreak
        case ("POST", "/v1/breaks/snooze"):
            guard let minutes = positiveMinutes(query["minutes"]) else { return nil }
            return .snooze(minutes: minutes)
        case ("POST", "/v1/focus"):
            guard let minutes = positiveMinutes(query["minutes"]) else { return nil }
            return .focus(minutes: minutes)
        case ("POST", "/v1/reminders/resume"):
            return .resume
        case ("POST", "/v1/stats/reset"):
            return .resetStats
        case ("POST", "/v1/ui/settings"):
            return .openSettings
        case ("POST", "/v1/ui/onboarding"):
            return .openOnboarding
        default:
            return nil
        }
    }

    private static func positiveMinutes(_ text: String?) -> Int? {
        guard let text, let minutes = Int(text), minutes > 0, minutes <= 24 * 60 else {
            return nil
        }
        return minutes
    }
}
