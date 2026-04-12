import Foundation

/// Tracks the daily 30-minute "cheat" budget.
/// Users can temporarily view blocked apps using cheat time without losing their streak.
/// Budget resets at the start of each new calendar day.
enum CheatBudgetTracker {
    static let dailyBudgetSeconds: TimeInterval = 1800

    private static let usedSecondsKey = "stillCheatUsedSeconds"
    private static let cheatDateKey = "stillCheatDate"
    private static let cheatActiveKey = "stillCheatActive"
    private static let cheatStartKey = "stillCheatStart"
    /// Cleared when cheat ends; if left set, UI/Live Activity can treat a Focus session as Still Mode.
    private static let cheatSourceModeKey = "stillCheatSourceMode"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    // MARK: - Budget

    /// Remaining cheat seconds for today (includes elapsed time of an active cheat session).
    static func remainingSeconds() -> TimeInterval {
        resetIfNewDay()
        let totalUsed = totalUsedTodayIncludingActive()
        return max(0, dailyBudgetSeconds - totalUsed)
    }

    /// Formatted remaining minutes for display.
    static func remainingMinutesText() -> String {
        let remaining = remainingSeconds()
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        if mins > 0 { return "\(mins)m" }
        return "\(secs)s"
    }

    static var budgetExhausted: Bool {
        remainingSeconds() <= 0
    }

    // MARK: - Cheat session

    static var isCheatActive: Bool {
        // `resetIfNewDay` must run before reading `cheatActiveKey`: a stale empty `stillCheatDate`
        // used to clear an in-flight cheat written by the shield extension before the app saw the date key.
        resetIfNewDay()
        guard defaults?.bool(forKey: cheatActiveKey) == true else { return false }
        if budgetExhausted {
            endCheat()
            return false
        }
        return true
    }

    /// Wall-clock start of the current cheat session (for Live Activity `startDate`). Must match `stillCheatStart` in app group.
    static func activeCheatStartDate() -> Date {
        let epoch = defaults?.double(forKey: cheatStartKey) ?? 0
        guard epoch > 0 else { return Date() }
        return Date(timeIntervalSince1970: epoch)
    }

    /// Start a cheat session — temporarily lifts shields.
    static func startCheat() {
        resetIfNewDay()
        guard !budgetExhausted else { return }
        defaults?.set(true, forKey: cheatActiveKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: cheatStartKey)
        defaults?.synchronize()
    }

    /// End the current cheat session and deduct used time from budget (through `closingTime`, not wall-clock now).
    static func endCheat(at closingTime: Date) {
        resetIfNewDay()
        guard defaults?.bool(forKey: cheatActiveKey) == true else { return }
        let startEpoch = defaults?.double(forKey: cheatStartKey) ?? closingTime.timeIntervalSince1970
        let start = Date(timeIntervalSince1970: startEpoch)
        let elapsed = max(0, closingTime.timeIntervalSince(start))
        let used = defaults?.double(forKey: usedSecondsKey) ?? 0
        defaults?.set(min(used + elapsed, dailyBudgetSeconds), forKey: usedSecondsKey)
        defaults?.set(false, forKey: cheatActiveKey)
        defaults?.removeObject(forKey: cheatStartKey)
        defaults?.removeObject(forKey: cheatSourceModeKey)
        defaults?.synchronize()
    }

    /// End the current cheat session and deduct used time from budget through now.
    static func endCheat() {
        endCheat(at: Date())
    }

    /// When a scheduled focus block ends while the user is on a focus cheat, stop the cheat at the block end so post-block app use is not billed or shown as cheating.
    static func endScheduledFocusCheatIfNeeded(sessionEnd: Date) {
        resetIfNewDay()
        guard defaults?.bool(forKey: cheatActiveKey) == true else { return }
        let mode = defaults?.string(forKey: cheatSourceModeKey) ?? ""
        guard mode == "focus" else { return }
        endCheat(at: sessionEnd)
    }

    /// How many seconds have been consumed including any active cheat session.
    static func totalUsedTodayIncludingActive() -> TimeInterval {
        resetIfNewDay()
        var used = defaults?.double(forKey: usedSecondsKey) ?? 0
        if defaults?.bool(forKey: cheatActiveKey) == true {
            let startEpoch = defaults?.double(forKey: cheatStartKey) ?? Date().timeIntervalSince1970
            used += Date().timeIntervalSince1970 - startEpoch
        }
        return min(used, dailyBudgetSeconds)
    }

    // MARK: - Day reset

    private static func resetIfNewDay() {
        let todayKey = DailyFocusLog.key(for: Date())
        let storedDate = defaults?.string(forKey: cheatDateKey) ?? ""
        if storedDate == todayKey { return }

        // First time we see the cheat date key (missing in app group): only stamp today.
        // Do not clear `stillCheatActive` / usage — the shield extension may have just written them.
        if storedDate.isEmpty {
            defaults?.set(todayKey, forKey: cheatDateKey)
            defaults?.synchronize()
            return
        }

        // Calendar day changed: reset daily cheat budget and end any session.
        defaults?.set(todayKey, forKey: cheatDateKey)
        defaults?.set(0.0, forKey: usedSecondsKey)
        defaults?.set(false, forKey: cheatActiveKey)
        defaults?.removeObject(forKey: cheatStartKey)
        defaults?.removeObject(forKey: cheatSourceModeKey)
        defaults?.synchronize()
    }
}
