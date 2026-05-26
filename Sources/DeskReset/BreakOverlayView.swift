import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: controller.activeEvent?.kind == .movement ? "figure.walk" : "eye")
                    .font(.system(size: 46, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    Text(controller.activeRoutine?.title ?? controller.activeTitle)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text(controller.activeSubtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                Text(controller.activeRemainingText)
                    .font(.system(size: 56, weight: .medium, design: .rounded))
                    .monospacedDigit()

                if let routine = controller.activeRoutine {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(routine.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(.thinMaterial, in: Circle())
                                Text(step)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button {
                        controller.completeBreak()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)

                    Button {
                        controller.snooze(minutes: controller.settings.snoozeMinutes)
                    } label: {
                        Label("Snooze \(controller.settings.snoozeMinutes)", systemImage: "clock")
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.settings.strictMode)

                    Button {
                        controller.skipBreak()
                    } label: {
                        Label("Skip", systemImage: "forward")
                    }
                    .buttonStyle(.borderless)
                    .disabled(controller.settings.strictMode)
                }
            }
            .padding(40)
            .frame(width: 680)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
        }
    }
}
