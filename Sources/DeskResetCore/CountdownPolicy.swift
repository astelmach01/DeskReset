import Foundation

public enum CountdownPolicy {
    public static func shouldPauseVisibleCountdown(
        idleSeconds: TimeInterval,
        naturalBreakThreshold: TimeInterval,
        facePresent: Bool
    ) -> Bool {
        false
    }
}
