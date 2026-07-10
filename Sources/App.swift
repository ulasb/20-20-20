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

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let engine = Engine()
    let overlay = OverlayController()
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    private var lastSymbol = ""
    private var lastTitle = ""
    private lazy var eyeWithCameraBadge = Self.makeBadgedEye()

    /// The regular eye with a small camera badged into the bottom-right
    /// corner, punched out of the eye's outline so it stays legible. Template
    /// image, so the menu bar tints it for light/dark appearances.
    private static func makeBadgedEye() -> NSImage? {
        let eyeConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let badgeConfig = NSImage.SymbolConfiguration(pointSize: 6, weight: .bold)
        guard
            let eye = NSImage(systemSymbolName: "eye", accessibilityDescription: "20-20-20")?
                .withSymbolConfiguration(eyeConfig),
            let camera = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(badgeConfig)
        else { return nil }

        let size = NSSize(width: eye.size.width + 2, height: eye.size.height + 2)
        let image = NSImage(size: size, flipped: false) { _ in
            eye.draw(in: NSRect(x: 0, y: 2, width: eye.size.width, height: eye.size.height))
            let badge = NSRect(
                x: size.width - camera.size.width, y: 0,
                width: camera.size.width, height: camera.size.height
            )
            NSColor.black.setFill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(roundedRect: badge.insetBy(dx: -1.2, dy: -1.2), xRadius: 2.5, yRadius: 2.5).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            camera.draw(in: badge)
            return true
        }
        image.isTemplate = true
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "20-20-20")
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self

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
            let host = NSHostingController(rootView: PopoverView(engine: engine))
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Tear the SwiftUI view down while hidden so the engine's once-a-second
    // published updates don't keep an off-screen view hierarchy busy.
    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }

        let symbol: String
        switch engine.phase {
        case .working: symbol = engine.inCallNow ? "eye+camera" : "eye"
        case .paused: symbol = "eye.slash"
        case .deferred: symbol = "eye+camera"
        case .onBreak: symbol = "eye.fill"
        }

        let title: String
        switch (engine.phase, Settings.showCountdown) {
        case (.paused, _), (_, false):
            title = ""
        case (.deferred, _):
            title = " due"
        case (.onBreak, _):
            title = String(format: " :%02d", max(0, Int(engine.remaining.rounded(.up))))
        default:
            let s = max(0, Int(engine.remaining.rounded(.up)))
            title = String(format: " %d:%02d", s / 60, s % 60)
        }

        if symbol != lastSymbol {
            button.image = symbol == "eye+camera"
                ? eyeWithCameraBadge
                : NSImage(systemSymbolName: symbol, accessibilityDescription: "20-20-20")
            lastSymbol = symbol
        }
        if title != lastTitle {
            button.title = title
            lastTitle = title
        }
    }

    private func playSound(_ name: String) {
        guard Settings.soundOn else { return }
        NSSound(named: name)?.play()
    }
}
