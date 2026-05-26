import SwiftUI

struct OnboardingView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DeskReset")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                Text("A calmer break coach for long computer sessions.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                OnboardingRow(
                    symbol: "eye",
                    title: "Protect your eyes",
                    text: "Short 20-second resets help you look away before strain accumulates."
                )
                OnboardingRow(
                    symbol: "figure.walk",
                    title: "Move before stiffness sets in",
                    text: "Longer movement breaks nudge you to stand, walk, stretch, and reset posture."
                )
                OnboardingRow(
                    symbol: "moon",
                    title: "Respect quiet hours",
                    text: "Pause reminders at night or during off-hours so recovery stays recovery."
                )
                OnboardingRow(
                    symbol: "brain.head.profile",
                    title: "Keep deep work intact",
                    text: "Use focus pauses when you need uninterrupted flow."
                )
            }

            DeskResetCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended starter setup")
                        .font(.headline)
                    Toggle("Eye break: 20 seconds every 20 minutes", isOn: controller.binding(\.microEnabled))
                    Toggle("Movement break: 5 minutes every hour", isOn: controller.binding(\.movementEnabled))
                    Toggle("Use a visible overlay", isOn: controller.binding(\.overlayEnabled))
                    Toggle("Send notifications", isOn: controller.binding(\.notificationsEnabled))
                }
            }

            HStack {
                Button("Customize") {
                    controller.finishOnboarding()
                    controller.openSettings()
                }
                Spacer()
                Button("Start") {
                    controller.finishOnboarding()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct OnboardingRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
