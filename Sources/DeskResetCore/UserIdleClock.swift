import CoreGraphics
import Foundation

public enum UserIdleClock {
    public static let eventSourceStateID: CGEventSourceStateID = .hidSystemState

    public static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(eventSourceStateID, eventType: .null)
    }
}
