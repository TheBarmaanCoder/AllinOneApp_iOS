import Foundation

/// Computes the current consecutive-day streak from DailyFocusLog.
/// A day "counts" if the user focused for at least 30 minutes total.
enum StreakTracker {
    private static let minimumSeconds: TimeInterval = 1800
    private static let streakKey = "stillCurrentStreak"
    private static let lastStreakDateKey = "stillLastStreakDate"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    /// Current streak in consecutive days.
    static func currentStreak() -> Int {
        let log = DailyFocusLog.loadAll()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let todayKey = DailyFocusLog.key(for: today)
        let todayHasActivity = (log[todayKey] ?? 0) >= minimumSeconds
        guard todayHasActivity else { return 0 }

        var checkDate = today
        var streak = 0

        while true {
            let k = DailyFocusLog.key(for: checkDate)
            let secs = log[k] ?? 0
            if secs >= minimumSeconds {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    /// Whether today has met the minimum focus threshold (used for streak UI).
    static func todayCompleted() -> Bool {
        DailyFocusLog.todaySeconds() >= minimumSeconds
    }
}
