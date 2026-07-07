import Foundation
import Combine

/// Daily break stats plus a consecutive-day streak, persisted in UserDefaults.
/// Counts reset at midnight; the streak survives as long as at least one
/// break is completed every day.
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var breaksCompleted = 0
    @Published private(set) var manualSkips = 0
    @Published private(set) var autoSkips = 0
    @Published private(set) var dayStreak = 0

    private let defaults = UserDefaults.standard
    private var day: String

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        day = Self.key(Date())
        if defaults.string(forKey: "stats.day") == day {
            breaksCompleted = defaults.integer(forKey: "stats.completed")
            manualSkips = defaults.integer(forKey: "stats.manualSkips")
            autoSkips = defaults.integer(forKey: "stats.autoSkips")
        }
        dayStreak = currentStreak()
    }

    func recordCompleted() {
        rolloverIfNeeded()
        breaksCompleted += 1

        let lastDay = defaults.string(forKey: "streak.lastDay")
        if lastDay != day {
            let continued = lastDay == Self.key(Self.yesterday())
            let streak = continued ? defaults.integer(forKey: "streak.count") + 1 : 1
            defaults.set(streak, forKey: "streak.count")
            defaults.set(day, forKey: "streak.lastDay")
            dayStreak = streak
        }
        persist()
    }

    func recordManualSkip() {
        rolloverIfNeeded()
        manualSkips += 1
        persist()
    }

    func recordAutoSkip() {
        rolloverIfNeeded()
        autoSkips += 1
        persist()
    }

    func rolloverIfNeeded() {
        let today = Self.key(Date())
        guard today != day else { return }
        day = today
        breaksCompleted = 0
        manualSkips = 0
        autoSkips = 0
        dayStreak = currentStreak()
        persist()
    }

    /// Streak is only alive if the last completed break was today or yesterday.
    private func currentStreak() -> Int {
        guard let lastDay = defaults.string(forKey: "streak.lastDay"),
              lastDay == day || lastDay == Self.key(Self.yesterday())
        else { return 0 }
        return defaults.integer(forKey: "streak.count")
    }

    private func persist() {
        defaults.set(day, forKey: "stats.day")
        defaults.set(breaksCompleted, forKey: "stats.completed")
        defaults.set(manualSkips, forKey: "stats.manualSkips")
        defaults.set(autoSkips, forKey: "stats.autoSkips")
    }

    private static func key(_ date: Date) -> String { dayFormatter.string(from: date) }

    private static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
}
