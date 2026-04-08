import ActivityKit
import Foundation

/// Serializes all Live Activity updates so concurrent `Task`s cannot interleave stop/start and drop the Dynamic Island / lock screen timer.
@available(iOS 16.2, *)
private actor LiveActivityCoordinator {
    static let shared = LiveActivityCoordinator()

    func stopAllActivities() async {
        let state = StillTimerAttributes.ContentState(startDate: Date(), endDate: Date())
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<StillTimerAttributes>.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    func replaceWith(mode: StillTimerAttributes.Mode, label: String, startDate: Date, endDate: Date?) async {
        await stopAllActivities()
        await request(mode: mode, label: label, startDate: startDate, endDate: endDate)
    }

    func syncToAppState(stillModeActive: Bool, isSessionActive: Bool, sessionEndsAt: Date?) async {
        let store = AppGroupStore.shared
        await stopAllActivities()
        if stillModeActive {
            let start = store.stillModeStart ?? Date()
            await request(mode: .stillMode, label: "Still Mode", startDate: start, endDate: nil)
        } else if isSessionActive, let end = sessionEndsAt {
            let start = store.sessionStart ?? Date()
            await request(mode: .focus, label: "Focus Mode", startDate: start, endDate: end)
        }
    }

    private func request(mode: StillTimerAttributes.Mode, label: String, startDate: Date, endDate: Date?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs = StillTimerAttributes(mode: mode, label: label)
        let state = StillTimerAttributes.ContentState(startDate: startDate, endDate: endDate)
        let activityContent = ActivityContent(state: state, staleDate: nil)

        do {
            _ = try Activity.request(
                attributes: attrs,
                content: activityContent,
                pushType: nil
            )
        } catch {
            // Live Activity not available on this device
        }
    }
}

/// Manages the Still live activity (lock screen / dynamic island timer).
enum LiveActivityManager {
    // MARK: - Start

    static func startFocusTimer(endsAt: Date) {
        guard #available(iOS 16.2, *) else { return }
        let start = AppGroupStore.shared.sessionStart ?? Date()
        Task {
            await LiveActivityCoordinator.shared.replaceWith(mode: .focus, label: "Focus Mode", startDate: start, endDate: endsAt)
        }
    }

    static func startStillModeTimer() {
        guard #available(iOS 16.2, *) else { return }
        let start = AppGroupStore.shared.stillModeStart ?? Date()
        Task {
            await LiveActivityCoordinator.shared.replaceWith(mode: .stillMode, label: "Still Mode", startDate: start, endDate: nil)
        }
    }

    static func startCheatTimer(endsAt: Date) {
        guard #available(iOS 16.2, *) else { return }
        let start = CheatBudgetTracker.activeCheatStartDate()
        Task {
            await LiveActivityCoordinator.shared.replaceWith(mode: .cheat, label: "Cheat Timer", startDate: start, endDate: endsAt)
        }
    }

    static func syncToAppState(stillModeActive: Bool, isSessionActive: Bool, sessionEndsAt: Date?) {
        guard #available(iOS 16.2, *) else { return }
        Task {
            await LiveActivityCoordinator.shared.syncToAppState(
                stillModeActive: stillModeActive,
                isSessionActive: isSessionActive,
                sessionEndsAt: sessionEndsAt
            )
        }
    }

    // MARK: - Stop

    static func stop() {
        guard #available(iOS 16.2, *) else { return }
        Task {
            await LiveActivityCoordinator.shared.stopAllActivities()
        }
    }
}
