import AppKit
import SwiftUI

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = Engine()
    let overlay = OverlayController()
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "20-20-20")
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.action = #selector(togglePopover)
            button.target = self
        }

        let host = NSHostingController(rootView: PopoverView(engine: engine))
        host.sizingOptions = [.preferredContentSize]
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = host

        engine.isCallActive = { Settings.skipInCalls && MeetingDetector.inCall }
        engine.onBreakDeferred = { StatsStore.shared.recordAutoSkip() }
        engine.onBreakStart = { [weak self] in
            guard let self else { return }
            if self.popover.isShown { self.popover.performClose(nil) }
            self.playSound("Purr")
            self.overlay.show(duration: self.engine.breakDuration) { [weak self] in
                self?.engine.endBreak(.skipped)
            }
        }
        engine.onBreakEnd = { [weak self] reason in
            switch reason {
            case .completed:
                StatsStore.shared.recordCompleted()
                self?.playSound("Glass")
            case .skipped:
                StatsStore.shared.recordManualSkip()
            case .abandoned:
                break
            }
            self?.overlay.dismiss()
        }
        engine.onTick = { [weak self] in self?.updateStatus() }

        engine.start()
        updateStatus()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }

        let symbol: String
        switch engine.phase {
        case .working: symbol = "eye"
        case .paused: symbol = "eye.slash"
        case .deferred: symbol = "video.fill"
        case .onBreak: symbol = "eye.fill"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "20-20-20")

        switch (engine.phase, Settings.showCountdown) {
        case (.paused, _), (_, false):
            button.title = ""
        case (.deferred, _):
            button.title = " due"
        case (.onBreak, _):
            button.title = String(format: " :%02d", max(0, Int(engine.remaining.rounded(.up))))
        default:
            let s = max(0, Int(engine.remaining.rounded(.up)))
            button.title = String(format: " %d:%02d", s / 60, s % 60)
        }
    }

    private func playSound(_ name: String) {
        guard Settings.soundOn else { return }
        NSSound(named: name)?.play()
    }
}
