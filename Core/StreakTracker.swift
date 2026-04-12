import Foundation

/// Computes the current consecutive-day streak from DailyFocusLog.
/// A day counts if either:
/// - total focus >= 2 hours, OR
/// - total focus >= 30 minutes and there were no manual session breaks.
enum StreakTracker {
    private static let qualityMinimumSeconds: TimeInterval = 1800
    private static let volumeMinimumSeconds: TimeInterval = 7200
    private static let manualBreaksKey = "stillManualBreaksByDay"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    /// Current streak in consecutive days.
    static func currentStreak() -> Int {
        let log = DailyFocusLog.loadAll()
        let breaks = loadManualBreaksByDay()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let todayKey = DailyFocusLog.key(for: today)
        guard dayCounts(
            focusedSeconds: log[todayKey] ?? 0,
            manualBreakCount: breaks[todayKey] ?? 0
        ) else { return 0 }

        var checkDate = today
        var streak = 0

        while true {
            let k = DailyFocusLog.key(for: checkDate)
            let secs = log[k] ?? 0
            let breakCount = breaks[k] ?? 0
            if dayCounts(focusedSeconds: secs, manualBreakCount: breakCount) {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    /// Whether today currently satisfies the streak rule.
    static func todayCompleted() -> Bool {
        let key = DailyFocusLog.key(for: Date())
        let focusedSeconds = DailyFocusLog.todaySeconds()
        let breaks = loadManualBreaksByDay()
        return dayCounts(
            focusedSeconds: focusedSeconds,
            manualBreakCount: breaks[key] ?? 0
        )
    }

    /// Records one manual break for today. Cheats are intentionally excluded.
    static func markManualBreak(for date: Date = Date()) {
        let key = DailyFocusLog.key(for: date)
        var breaks = loadManualBreaksByDay()
        breaks[key, default: 0] += 1
        saveManualBreaksByDay(breaks)
    }

    private static func dayCounts(focusedSeconds: TimeInterval, manualBreakCount: Int) -> Bool {
        if focusedSeconds >= volumeMinimumSeconds { return true }
        return focusedSeconds >= qualityMinimumSeconds && manualBreakCount == 0
    }

    private static func loadManualBreaksByDay() -> [String: Int] {
        guard let data = defaults?.data(forKey: manualBreaksKey),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }

    private static func saveManualBreaksByDay(_ breaks: [String: Int]) {
        guard let data = try? JSONEncoder().encode(breaks) else { return }
        defaults?.set(data, forKey: manualBreaksKey)
    }
}
