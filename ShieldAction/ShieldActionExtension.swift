import ActivityKit
import ManagedSettings
import ManagedSettingsUI
import DeviceActivity
import Foundation

@objc(ShieldActionExtension)
final class ShieldActionExtension: ShieldActionDelegate {
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private let cheatPrefix = AppConstants.cheatDeviceActivityNamePrefix

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    // MARK: - Shared logic

    private func handleAction(
        _ action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)

        case .secondaryButtonPressed:
            let defaults = UserDefaults(suiteName: AppConstants.appGroupId)
            // Merge in writes from the main app (e.g. endCheat) before we read remaining budget.
            defaults?.synchronize()
            resetIfNewDay(defaults: defaults)
            reconcileExhaustedActiveCheatIfNeeded(defaults: defaults)

            let remaining = cheatRemaining(defaults: defaults)

            guard remaining > 0 else {
                completionHandler(.close)
                return
            }

            if #available(iOS 16.2, *) {
                Task {
                    await Self.endAllStillTimerLiveActivitiesForCheatStart()
                }
            }

            startCheat(defaults: defaults)
            scheduleCheatExpiry(after: remaining)
            store.clearAllSettings()
            defaults?.synchronize()
            completionHandler(.defer)

        case .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Cheat budget (mirror of CheatBudgetTracker logic)

    /// If `stillCheatActive` is true but budget is exhausted, fold into `used` and clear — same as `CheatBudgetTracker.endCheat()`.
    private func reconcileExhaustedActiveCheatIfNeeded(defaults: UserDefaults?) {
        guard defaults?.bool(forKey: "stillCheatActive") == true else { return }
        let remaining = cheatRemaining(defaults: defaults)
        guard remaining <= 0 else { return }
        mirrorEndCheat(defaults: defaults)
    }

    private func mirrorEndCheat(defaults: UserDefaults?) {
        guard defaults?.bool(forKey: "stillCheatActive") == true else { return }
        let startEpoch = defaults?.double(forKey: "stillCheatStart") ?? Date().timeIntervalSince1970
        let elapsed = Date().timeIntervalSince1970 - startEpoch
        let used = defaults?.double(forKey: "stillCheatUsedSeconds") ?? 0
        defaults?.set(used + elapsed, forKey: "stillCheatUsedSeconds")
        defaults?.set(false, forKey: "stillCheatActive")
        defaults?.removeObject(forKey: "stillCheatStart")
        defaults?.removeObject(forKey: "stillCheatSourceMode")
        defaults?.synchronize()
    }

    /// Mirrors `CheatBudgetTracker.remainingSeconds()` (includes elapsed time of an in-flight cheat).
    private func cheatRemaining(defaults: UserDefaults?) -> Double {
        resetIfNewDay(defaults: defaults)
        var used = defaults?.double(forKey: "stillCheatUsedSeconds") ?? 0
        if defaults?.bool(forKey: "stillCheatActive") == true {
            let startEpoch = defaults?.double(forKey: "stillCheatStart") ?? Date().timeIntervalSince1970
            used += Date().timeIntervalSince1970 - startEpoch
        }
        return max(0, 1800 - used)
    }

    private func startCheat(defaults: UserDefaults?) {
        resetIfNewDay(defaults: defaults)
        defaults?.set(true, forKey: "stillCheatActive")
        defaults?.set(Date().timeIntervalSince1970, forKey: "stillCheatStart")

        // Persist cheat origin so the app can offer the right re-engage button.
        let isStillMode = defaults?.bool(forKey: "stillModeActive") ?? false
        defaults?.set(isStillMode ? "still" : "focus", forKey: "stillCheatSourceMode")

        // Show one-time in-app warning right after tapping Cheat.
        defaults?.set(true, forKey: "stillCheatShowWarning")
    }

    /// Device Activity requires schedules ≥ 15 minutes. For shorter cheat windows, we use a 15‑minute
    /// interval and `warningTime` so `intervalWillEndWarning` fires when the real cheat ends.
    private func scheduleCheatExpiry(after remaining: Double) {
        let r = max(1.0, remaining)
        let active = center.activities.filter { $0.rawValue.hasPrefix(cheatPrefix) }
        if !active.isEmpty { center.stopMonitoring(active) }

        let now = Date()
        let cal = Calendar.current
        let minScheduleSeconds: TimeInterval = 15 * 60

        let startComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: now)
        let endDate: Date
        let warningBeforeIntervalEnd: DateComponents?

        if r >= minScheduleSeconds {
            endDate = now.addingTimeInterval(r)
            warningBeforeIntervalEnd = nil
        } else {
            endDate = now.addingTimeInterval(minScheduleSeconds)
            let secondsBeforeEnd = Int(minScheduleSeconds - r)
            warningBeforeIntervalEnd = dateComponentsBeforeIntervalEnd(seconds: secondsBeforeEnd)
        }

        let endComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: endDate)

        let schedule: DeviceActivitySchedule
        if let warning = warningBeforeIntervalEnd {
            schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false,
                warningTime: warning
            )
        } else {
            schedule = DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: false)
        }

        let name = DeviceActivityName("\(cheatPrefix)\(Int(now.timeIntervalSince1970))")

        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            // If scheduling fails, app-side sync still re-applies shields on next foreground.
        }
    }

    private func dateComponentsBeforeIntervalEnd(seconds: Int) -> DateComponents {
        let clamped = max(1, min(seconds, 15 * 60 - 1))
        var c = DateComponents()
        c.hour = clamped / 3600
        c.minute = (clamped % 3600) / 60
        c.second = clamped % 60
        return c
    }

    private func resetIfNewDay(defaults: UserDefaults?) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let todayKey = fmt.string(from: Date())
        let stored = defaults?.string(forKey: "stillCheatDate") ?? ""
        if stored == todayKey { return }

        if stored.isEmpty {
            defaults?.set(todayKey, forKey: "stillCheatDate")
            defaults?.synchronize()
            return
        }

        defaults?.set(todayKey, forKey: "stillCheatDate")
        defaults?.set(0.0, forKey: "stillCheatUsedSeconds")
        defaults?.set(false, forKey: "stillCheatActive")
        defaults?.removeObject(forKey: "stillCheatStart")
        defaults?.removeObject(forKey: "stillCheatSourceMode")
        defaults?.synchronize()
    }

    // MARK: - Live Activity (end focus/still timer as soon as Cheat is pressed)

    @available(iOS 16.2, *)
    private static func endAllStillTimerLiveActivitiesForCheatStart() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = StillTimerAttributes.ContentState(startDate: Date(), endDate: Date())
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<StillTimerAttributes>.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }
}
