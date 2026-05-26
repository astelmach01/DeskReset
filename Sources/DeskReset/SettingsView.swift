import DeskResetCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @State private var selectedSection: SettingsSection = .schedule

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                header
                ScrollView {
                    content
                        .padding(.bottom, 18)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DeskReset")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.top, 18)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedSection == section ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSection == section ? Color.accentColor.opacity(0.14) : .clear)
                )
                .padding(.horizontal, 8)
            }

            Spacer()
            Text("Local first")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
        }
        .frame(width: 168)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selectedSection.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(selectedSection.subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(controller.remainingText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .schedule:
            VStack(spacing: 14) {
                BreakRuleCard(
                    title: "Eye Break",
                    subtitle: "Look away and soften your focus.",
                    enabled: controller.binding(\.microEnabled),
                    interval: controller.binding(\.microInterval),
                    duration: controller.binding(\.microDuration),
                    intervalRange: 5...60,
                    durationRange: 10...120,
                    durationUnit: "sec"
                )
                BreakRuleCard(
                    title: "Movement Break",
                    subtitle: "Stand, walk, stretch, or reset posture.",
                    enabled: controller.binding(\.movementEnabled),
                    interval: controller.binding(\.movementInterval),
                    duration: controller.binding(\.movementDuration),
                    intervalRange: 30...180,
                    durationRange: 1...15,
                    durationUnit: "min"
                )
                QuietHoursCard(controller: controller)
            }
        case .awareness:
            VStack(spacing: 14) {
                IdleResetCard(controller: controller)
                HeadsUpCard(controller: controller)
                MeetingCard(controller: controller)
                SmartDetectionCard(controller: controller)
            }
        case .controls:
            VStack(spacing: 14) {
                BehaviorCard(controller: controller)
                SafetyCard(controller: controller)
                APICard(controller: controller)
            }
        case .stats:
            VStack(spacing: 14) {
                StatsCard(controller: controller)
                RoutineCard()
            }
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case schedule
    case awareness
    case controls
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .awareness: return "Awareness"
        case .controls: return "Controls"
        case .stats: return "Stats"
        }
    }

    var subtitle: String {
        switch self {
        case .schedule: return "Tune the cadence for eyes, posture, and quiet time."
        case .awareness: return "Count natural resets and avoid interrupting calls."
        case .controls: return "Adjust overlays, focus pauses, startup, and API access."
        case .stats: return "See completed breaks and available routines."
        }
    }

    var symbol: String {
        switch self {
        case .schedule: return "clock"
        case .awareness: return "eye"
        case .controls: return "slider.horizontal.3"
        case .stats: return "chart.bar"
        }
    }
}

private struct APICard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Local API", isOn: controller.binding(\.apiEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)

                HStack(spacing: 14) {
                    Text("Port")
                        .foregroundStyle(.secondary)
                    TextField(
                        "17777",
                        value: controller.binding(\.apiPort),
                        formatter: NumberFormatter()
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    Text("127.0.0.1 only")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .disabled(!controller.settings.apiEnabled)
                .opacity(controller.settings.apiEnabled ? 1 : 0.45)

                Text("Use deskresetctl or curl to start breaks, snooze, focus, inspect status, and update settings headlessly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BreakRuleCard: View {
    let title: String
    let subtitle: String
    @Binding var enabled: Bool
    @Binding var interval: TimeInterval
    @Binding var duration: TimeInterval
    let intervalRange: ClosedRange<Double>
    let durationRange: ClosedRange<Double>
    let durationUnit: String

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $enabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                controlRow(
                    label: "Every",
                    value: Binding(
                        get: { interval / 60 },
                        set: { interval = $0 * 60 }
                    ),
                    range: intervalRange,
                    suffix: "min"
                )

                controlRow(
                    label: "For",
                    value: Binding(
                        get: { durationUnit == "sec" ? duration : duration / 60 },
                        set: { duration = durationUnit == "sec" ? $0 : $0 * 60 }
                    ),
                    range: durationRange,
                    suffix: durationUnit
                )
            }
        }
    }

    private func controlRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .frame(width: 46, alignment: .leading)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range, step: 1)
            Text("\(Int(value.wrappedValue)) \(suffix)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 72, alignment: .trailing)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

private struct QuietHoursCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Quiet hours", isOn: controller.binding(\.quietHoursEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)

                HStack {
                    TimeEditor(label: "From", time: controller.binding(\.quietHoursStart))
                    Spacer()
                    TimeEditor(label: "Until", time: controller.binding(\.quietHoursEnd))
                }
                .disabled(!controller.settings.quietHoursEnabled)
                .opacity(controller.settings.quietHoursEnabled ? 1 : 0.45)
            }
        }
    }
}

private struct IdleResetCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Count natural breaks", isOn: controller.binding(\.idleResetEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)

                HStack(spacing: 14) {
                    Text("Reset after")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(controller.settings.idleResetMinutes) },
                            set: { controller.settings.idleResetMinutes = Int($0) }
                        ),
                        in: 2...20,
                        step: 1
                    )
                    Text("\(controller.settings.idleResetMinutes) min")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 74, alignment: .trailing)
                }
                .disabled(!controller.settings.idleResetEnabled)
                .opacity(controller.settings.idleResetEnabled ? 1 : 0.45)

                Text("Timers count active computer use. Step away and the schedule pauses; stay away long enough and it counts as a natural break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HeadsUpCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Heads-up warning", isOn: controller.binding(\.headsUpEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)

                HStack(spacing: 14) {
                    Text("Warn")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(controller.settings.headsUpSeconds) },
                            set: { controller.settings.headsUpSeconds = Int($0) }
                        ),
                        in: 10...180,
                        step: 10
                    )
                    Text("\(controller.settings.headsUpSeconds) sec")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 74, alignment: .trailing)
                }
                .disabled(!controller.settings.headsUpEnabled)
                .opacity(controller.settings.headsUpEnabled ? 1 : 0.45)
            }
        }
    }
}

private struct MeetingCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Meeting guard", isOn: controller.binding(\.meetingDetectionEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)
                Text("Defers a due break during Zoom, Teams, FaceTime, Webex, browser meetings, and Slack huddles when macOS exposes the window signal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SmartDetectionCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Smart detection", isOn: controller.binding(\.smartDetectionEnabled))
                    .font(.headline)
                    .toggleStyle(.switch)

                HStack(spacing: 14) {
                    Text("Count away after")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(controller.settings.smartDetectionAwaySeconds) },
                            set: { controller.settings.smartDetectionAwaySeconds = Int($0) }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    Text("\(controller.settings.smartDetectionAwaySeconds) sec")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 74, alignment: .trailing)
                }
                .disabled(!controller.settings.smartDetectionEnabled)
                .opacity(controller.settings.smartDetectionEnabled ? 1 : 0.45)

                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Text(controller.smartDetection.status.rawValue)
                        .font(.system(.body, design: .monospaced))
                    if controller.smartDetection.facePresent {
                        Text("face present")
                            .foregroundStyle(.green)
                    } else if controller.settings.smartDetectionEnabled {
                        Text("away \(Int(controller.smartDetection.awaySeconds))s")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text("Uses Apple Vision locally to detect face presence. Frames are discarded immediately; no photos, videos, or gaze data are stored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BehaviorCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Behavior")
                    .font(.headline)
                Toggle("Show break overlay", isOn: controller.binding(\.overlayEnabled))
                Toggle("Send notifications", isOn: controller.binding(\.notificationsEnabled))
                Toggle("Launch at login", isOn: controller.binding(\.launchAtLogin))
                Toggle("Show overlay on all displays", isOn: controller.binding(\.showOverlayOnAllDisplays))
                Toggle("Strict break mode", isOn: controller.binding(\.strictMode))

                Divider()

                HStack {
                    Button("Focus 30") { controller.focus(minutes: 30) }
                    Button("Focus 60") { controller.focus(minutes: 60) }
                    Button("Focus 90") { controller.focus(minutes: 90) }
                    Spacer()
                    if controller.settings.pausedUntil != nil {
                        Button("Resume") { controller.clearPause() }
                    }
                }
            }
        }
    }
}

private struct SafetyCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Snooze")
                    .font(.headline)
                HStack(spacing: 14) {
                    Text("Default")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(controller.settings.snoozeMinutes) },
                            set: { controller.settings.snoozeMinutes = Int($0) }
                        ),
                        in: 1...20,
                        step: 1
                    )
                    Text("\(controller.settings.snoozeMinutes) min")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 74, alignment: .trailing)
                }

                Text("Strict mode raises break overlays above other windows. Keep it off if you prefer gentle reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatsCard: View {
    @ObservedObject var controller: AppController

    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Stats")
                        .font(.headline)
                    Spacer()
                    Button("Reset") { controller.resetStats() }
                }

                HStack(spacing: 10) {
                    StatPill(title: "Done", value: "\(controller.stats.completedBreaks)")
                    StatPill(title: "Moved", value: "\(controller.stats.movementBreaks)")
                    StatPill(title: "Snoozed", value: "\(controller.stats.snoozedBreaks)")
                    StatPill(title: "Skipped", value: "\(controller.stats.skippedBreaks)")
                    StatPill(title: "Time", value: AppController.formatRemaining(TimeInterval(controller.stats.mindfulSeconds)))
                }
            }
        }
    }
}

private struct RoutineCard: View {
    var body: some View {
        DeskResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Routine library")
                    .font(.headline)
                HStack(alignment: .top, spacing: 18) {
                    routineColumn(title: "Eyes", routines: BreakRoutine.eyeRoutines)
                    Divider()
                    routineColumn(title: "Movement", routines: BreakRoutine.movementRoutines)
                }
            }
        }
    }

    private func routineColumn(title: String, routines: [BreakRoutine]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(routines, id: \.title) { routine in
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                    Text(routine.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimeEditor: View {
    let label: String
    @Binding var time: TimeOfDay

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Stepper(value: $time.hour, in: 0...23) {
                Text(String(format: "%02d", time.hour))
                    .font(.system(.body, design: .monospaced))
            }
            Stepper(value: $time.minute, in: 0...59, step: 15) {
                Text(String(format: "%02d", time.minute))
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
