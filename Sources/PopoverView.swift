import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var engine: Engine
    @ObservedObject private var stats = StatsStore.shared

    @AppStorage("intervalMinutes") private var intervalMinutes = 20
    @AppStorage("breakSeconds") private var breakSeconds = 20
    @AppStorage("soundOn") private var soundOn = true
    @AppStorage("showCountdown") private var showCountdown = true
    @AppStorage("skipInCalls") private var skipInCalls = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 14) {
            ring
            controls
            Divider()
            statsSection
            Divider()
            settings
            Divider()
            HStack {
                Button("Quit 20-20-20") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
                Spacer()
                Text("20 min · 20 s · 20 ft")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 272)
        .onAppear { stats.rolloverIfNeeded() }
    }

    private var statsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if stats.dayStreak > 0 {
                    Label("\(stats.dayStreak)-day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            HStack(spacing: 8) {
                stat(stats.breaksCompleted, "breaks", "checkmark.circle.fill", .green)
                stat(stats.manualSkips, "skipped", "forward.circle.fill", .orange)
                stat(stats.autoSkips, "in calls", "video.circle.fill", .blue)
            }
        }
    }

    private func stat(_ count: Int, _ label: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var ring: some View {
        let total = engine.phase == .onBreak ? engine.breakDuration : engine.workDuration
        let fraction = total > 0 ? max(0, engine.remaining) / total : 0
        return ZStack {
            Circle().stroke(.quaternary, lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    engine.phase == .paused ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: fraction)
            VStack(spacing: 2) {
                if engine.phase == .deferred {
                    Image(systemName: "video.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.tint)
                } else {
                    Text(timeString)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 148, height: 148)
        .padding(.top, 4)
    }

    private var timeString: String {
        let s = max(0, Int(engine.remaining.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var caption: String {
        switch engine.phase {
        case .working: return "until your next break"
        case .paused: return "paused"
        case .deferred: return "break due after your call"
        case .onBreak: return "eyes off the screen"
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                engine.togglePause()
            } label: {
                Label(
                    engine.phase == .paused ? "Resume" : "Pause",
                    systemImage: engine.phase == .paused ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            Button {
                engine.beginBreak()
            } label: {
                Label("Break now", systemImage: "eyes")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        .disabled(engine.phase == .onBreak)
    }

    private var settings: some View {
        VStack(spacing: 10) {
            row("Remind every") {
                Picker("", selection: $intervalMinutes) {
                    ForEach([10, 15, 20, 25, 30, 45], id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: intervalMinutes) { _, _ in engine.clampToSettings() }
            }
            row("Break for") {
                Picker("", selection: $breakSeconds) {
                    ForEach([20, 30, 45, 60], id: \.self) { Text("\($0) s").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            row("Sound") {
                Toggle("", isOn: $soundOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            row("Hold during calls") {
                Toggle("", isOn: $skipInCalls).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            row("Timer in menu bar") {
                Toggle("", isOn: $showCountdown).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            row("Start at login") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .font(.system(size: 13))
    }

    private func row(_ label: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(label)
            Spacer()
            trailing()
        }
    }
}
