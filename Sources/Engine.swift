import AppKit
import Combine

/// Drives the 20-20-20 cycle: a work countdown, then a short break.
/// Freezes while you're away from the keyboard and refills after a long absence,
/// so you're never told to rest right after you already did.
final class Engine: ObservableObject {
    /// `deferred` = a break is due but you're on a call; it fires as soon as
    /// the call ends (rather than the interval silently restarting).
    enum Phase: Equatable { case working, onBreak, deferred, paused }

    /// How a break ended: on its own (counts toward the streak), skipped by
    /// the user (esc), or abandoned by a system event like waking from sleep
    /// (counts as nothing).
    enum BreakEnd { case completed, skipped, abandoned }

    @Published private(set) var phase: Phase = .working
    @Published private(set) var remaining: TimeInterval = 20 * 60

    var workDuration: TimeInterval { TimeInterval(max(1, Settings.intervalMinutes)) * 60 }
    var breakDuration: TimeInterval { TimeInterval(max(5, Settings.breakSeconds)) }

    /// Asked when a timed break comes due; returning true holds the break
    /// (deferred phase) until this stops returning true.
    var isCallActive: (() -> Bool)?
    var onBreakDeferred: (() -> Void)?
    var onBreakStart: (() -> Void)?
    var onBreakEnd: ((BreakEnd) -> Void)?
    var onTick: (() -> Void)?

    private var timer: Timer?
    private var lastTick = Date()
    private let idleFreezeThreshold: TimeInterval = 180
    /// The call must stay ended this long before the held break fires, so a
    /// brief mic drop mid-call (device switch, reconnect) doesn't trigger it.
    private let callClearDebounce: TimeInterval = 10
    private var callClearSeconds: TimeInterval = 0

    func start() {
        remaining = workDuration
        lastTick = Date()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(systemWoke), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(systemWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func systemWoke() {
        if phase == .onBreak { endBreak(.abandoned) } else { resetWork() }
    }

    private func tick() {
        let now = Date()
        let delta = min(now.timeIntervalSince(lastTick), 2)
        lastTick = now

        switch phase {
        case .paused:
            break
        case .working:
            let idle = Self.idleSeconds()
            if idle >= workDuration {
                remaining = workDuration
            } else if idle < idleFreezeThreshold {
                remaining -= delta
                if remaining <= 0 {
                    if isCallActive?() == true {
                        phase = .deferred
                        remaining = 0
                        callClearSeconds = 0
                        onBreakDeferred?()
                    } else {
                        beginBreak()
                    }
                }
            }
        case .deferred:
            if isCallActive?() == true {
                callClearSeconds = 0
            } else {
                callClearSeconds += delta
                let idle = Self.idleSeconds()
                if idle >= idleFreezeThreshold {
                    // Walked away after the call — that's a real rest.
                    resetWork()
                } else if callClearSeconds >= callClearDebounce, idle < callClearDebounce {
                    // Call is over and they're back at the screen: break time.
                    beginBreak()
                }
            }
        case .onBreak:
            remaining -= delta
            if remaining <= 0 { endBreak(.completed) }
        }
        onTick?()
    }

    func beginBreak() {
        guard phase != .onBreak else { return }
        phase = .onBreak
        remaining = breakDuration
        onBreakStart?()
    }

    func endBreak(_ reason: BreakEnd) {
        guard phase == .onBreak else { return }
        phase = .working
        remaining = workDuration
        lastTick = Date()
        onBreakEnd?(reason)
    }

    func resetWork() {
        phase = .working
        remaining = workDuration
        lastTick = Date()
    }

    func togglePause() {
        switch phase {
        case .working, .deferred: phase = .paused
        case .paused: phase = .working; lastTick = Date()
        case .onBreak: break
        }
    }

    /// Re-clamp the countdown after the interval setting shrinks.
    func clampToSettings() {
        if phase != .onBreak, remaining > workDuration { remaining = workDuration }
    }

    static func idleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }
}

enum Settings {
    static var intervalMinutes: Int { UserDefaults.standard.object(forKey: "intervalMinutes") as? Int ?? 20 }
    static var breakSeconds: Int { UserDefaults.standard.object(forKey: "breakSeconds") as? Int ?? 20 }
    static var soundOn: Bool { UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true }
    static var showCountdown: Bool { UserDefaults.standard.object(forKey: "showCountdown") as? Bool ?? true }
    static var skipInCalls: Bool { UserDefaults.standard.object(forKey: "skipInCalls") as? Bool ?? true }
}
