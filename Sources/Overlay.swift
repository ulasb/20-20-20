import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Puts a calm, dimmed countdown over every screen for the length of the break.
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?

    func show(duration: TimeInterval, onSkip: @escaping () -> Void) {
        dismiss(animated: false)
        let start = Date()

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none

            let view = BreakView(
                startDate: start,
                duration: duration,
                isPrimary: screen == NSScreen.screens.first,
                onSkip: onSkip
            )
            window.contentView = NSHostingView(rootView: view)
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // esc
                onSkip()
                return nil
            }
            return event
        }
    }

    func dismiss(animated: Bool = true) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.6
                closing.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: {
                closing.forEach { $0.orderOut(nil) }
            })
        } else {
            closing.forEach { $0.orderOut(nil) }
        }
    }
}

struct BreakView: View {
    let startDate: Date
    let duration: TimeInterval
    let isPrimary: Bool
    var onSkip: () -> Void

    // The ring is a single Core Animation and the seconds text updates once
    // per second — a continuously redrawing TimelineView(.animation) over a
    // full-screen blur costs 15-20% CPU on ProMotion displays.
    @State private var ringFraction: Double = 1

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            RadialGradient(
                colors: [
                    Color(hue: 0.56, saturation: 0.50, brightness: 0.20),
                    Color(hue: 0.62, saturation: 0.55, brightness: 0.06),
                ],
                center: .center, startRadius: 0, endRadius: 1100
            )
            .opacity(0.92)

            if isPrimary { content }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: duration)) { ringFraction = 0 }
        }
    }

    private var content: some View {
        VStack(spacing: 36) {
            Spacer()

            Image(systemName: "eye")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 10) {
                Text("Look somewhere far away")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Rest your eyes on something about 20 feet (6 m) away — and blink.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(
                        .white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    let left = max(0, duration - context.date.timeIntervalSince(startDate))
                    Text("\(Int(left.rounded(.up)))")
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 128, height: 128)

            Spacer()

            Button(action: onSkip) {
                Text("press esc to skip")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
        }
        .padding(40)
    }
}
