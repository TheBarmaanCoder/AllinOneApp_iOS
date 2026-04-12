import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum FocusSessionStartError: LocalizedError {
    case sessionAlreadyActive

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A focus session is already in progress."
        }
    }
}

@MainActor
final class FocusSessionController: ObservableObject {
    @Published private(set) var isSessionActive = false
    /// True when the active session was started by a scheduled block (no focus Live Activity; cheat Live Activity still allowed).
    @Published private(set) var isScheduledSession = false
    @Published private(set) var scheduledBlockId: String?
    @Published private(set) var sessionEndsAt: Date?
    @Published private(set) var plannedDuration: TimeInterval = 0
    @Published private(set) var isCheatActive = false
    @Published private(set) var cheatRemainingSeconds: TimeInterval = 0
    @Published private(set) var cheatSourceMode: String = "focus"

    private let groupStore = AppGroupStore.shared
    private let activityName = DeviceActivityName(AppConstants.activityRawName)
    private let center = DeviceActivityCenter()
    private var cheatTimer: Timer?

    init() {
        syncFromStore()
    }

    func syncFromStore() {
        groupStore.synchronizeForCrossProcessRead()
        completeNaturallyIfNeeded()
        groupStore.synchronizeForCrossProcessRead()
        isSessionActive = groupStore.sessionActive
        isScheduledSession = groupStore.sessionIsScheduled
        scheduledBlockId = groupStore.scheduledBlockSessionId
        sessionEndsAt = groupStore.sessionEnd
        if let start = groupStore.sessionStart, let end = groupStore.sessionEnd {
            plannedDuration = end.timeIntervalSince(start)
        } else {
            plannedDuration = 0
        }
        syncCheatState()
        // Keep lock screen / Dynamic Island aligned whenever we’re not in a cheat (cheat path updates LA inside syncCheatState).
        if !isCheatActive {
            restartLiveActivityForCurrentMode()
        }
    }

    // MARK: - Cheat management

    func syncCheatState() {
        groupStore.synchronizeForCrossProcessRead()
        let wasActive = isCheatActive
        isCheatActive = CheatBudgetTracker.isCheatActive
        cheatRemainingSeconds = CheatBudgetTracker.remainingSeconds()

        if !isCheatActive {
            cheatTimer?.invalidate()
            cheatTimer = nil
        }

        let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupId)
        if isCheatActive {
            if let source = groupDefaults?.string(forKey: "stillCheatSourceMode"), !source.isEmpty {
                cheatSourceMode = source
            } else {
                cheatSourceMode = groupStore.stillModeActive ? "still" : "focus"
            }
            // Cheat was started from Still Mode but `stillModeActive` was cleared — restore so overlay/LA stay consistent.
            if cheatSourceMode == "still", !groupStore.stillModeActive {
                groupStore.stillModeActive = true
                if groupStore.stillModeStart == nil {
                    groupStore.stillModeStart = Date()
                }
                NotificationCenter.default.post(name: .stillModeStoreNeedsSync, object: nil)
            }
        } else {
            cheatSourceMode = groupStore.stillModeActive ? "still" : "focus"
        }

        if isCheatActive {
            let cheatEnd = Date().addingTimeInterval(cheatRemainingSeconds)
            if !wasActive {
                ShieldApplicator.clearShields()
            }
            // Refresh whenever cheat is active so a failed first request retries, and the countdown stays correct.
            LiveActivityManager.startCheatTimer(endsAt: cheatEnd)
        }

        if isCheatActive && cheatTimer == nil {
            startCheatMonitor()
        }

        if wasActive && !isCheatActive {
            reapplyShieldsIfNeeded()
            restartLiveActivityForCurrentMode()
        }
    }

    func endCheatAndReblock() {
        CheatBudgetTracker.endCheat()
        stopAllCheatExpirySchedules()
        isCheatActive = false
        cheatRemainingSeconds = CheatBudgetTracker.remainingSeconds()
        cheatTimer?.invalidate()
        cheatTimer = nil
        cheatSourceMode = groupStore.stillModeActive ? "still" : "focus"
        reapplyShieldsIfNeeded()
        restartLiveActivityForCurrentMode()
        NotificationCenter.default.post(name: .stillModeStoreNeedsSync, object: nil)
    }

    private func startCheatMonitor() {
        cheatTimer?.invalidate()
        cheatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.cheatRemainingSeconds = CheatBudgetTracker.remainingSeconds()
                if CheatBudgetTracker.budgetExhausted || !CheatBudgetTracker.isCheatActive {
                    self.endCheatAndReblock()
                }
            }
        }
    }

    /// Stops `cheatCountdown_*` Device Activity monitors so `intervalWillEndWarning` cannot fire after the user ends a cheat in-app and break a subsequent cheat session.
    private func stopAllCheatExpirySchedules() {
        let prefix = AppConstants.cheatDeviceActivityNamePrefix
        let cheatActivities = center.activities.filter { $0.rawValue.hasPrefix(prefix) }
        if !cheatActivities.isEmpty {
            center.stopMonitoring(cheatActivities)
        }
    }

    private func reapplyShieldsIfNeeded() {
        guard isSessionActive || groupStore.stillModeActive else { return }
        let selData: Data?
        if groupStore.stillModeActive {
            selData = groupStore.stillModeSelectionData
        } else {
            selData = groupStore.loadSessionSelectionData()
        }
        guard let data = selData, let selection = try? SelectionCodec.decode(data) else { return }
        ShieldApplicator.applyShields(for: selection)
    }

    /// Starts focus for the merged selection. Persists selection for the monitor extension.
    func startFocus(durationMinutes: Int, selection: FamilyActivitySelection) throws {
        guard durationMinutes > 0 else { return }
        guard !groupStore.sessionActive else {
            throw FocusSessionStartError.sessionAlreadyActive
        }

        let data = try SelectionCodec.encode(selection)
        groupStore.persistSessionSelection(data)

        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        groupStore.sessionStart = now
        groupStore.sessionEnd = end
        groupStore.sessionActive = true
        groupStore.sessionIsScheduled = false
        groupStore.scheduledBlockSessionId = nil

        plannedDuration = end.timeIntervalSince(now)
        isSessionActive = true
        isScheduledSession = false
        scheduledBlockId = nil
        sessionEndsAt = end

        center.stopMonitoring([activityName])

        let schedule = Self.schedule(from: now, to: end)
        try center.startMonitoring(activityName, during: schedule)

        ShieldApplicator.applyShields(for: selection)
        LiveActivityManager.startFocusTimer(endsAt: end)
        CloudPreferencesSync.schedulePushDebounced()
    }

    /// Ends focus early: stops monitoring and clears shields. Counts elapsed time only (not the full plan).
    func breakFocusEarly() {
        let scheduledBlockIdToDisable = groupStore.sessionIsScheduled ? groupStore.scheduledBlockSessionId : nil

        StreakTracker.markManualBreak()
        if !groupStore.sessionIsScheduled {
            center.stopMonitoring([activityName])
        }
        ShieldApplicator.clearShields()
        if let start = groupStore.sessionStart {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0 {
                groupStore.totalFocusSeconds += elapsed
                DailyFocusLog.logSession(start: start, end: Date())
            }
        }
        disableScheduledBlockForEarlyBreak(blockIdString: scheduledBlockIdToDisable)
        groupStore.clearSessionMetadata()
        isSessionActive = false
        isScheduledSession = false
        scheduledBlockId = nil
        sessionEndsAt = nil
        plannedDuration = 0
        restartLiveActivityForCurrentMode()
        AchievementTracker.evaluateAndUnlock()
        CloudPreferencesSync.schedulePushDebounced()
    }

    /// Backup when the monitor extension has not run yet (e.g. Simulator): same accounting as `intervalDidEnd`.
    func completeNaturallyIfNeeded() {
        guard groupStore.sessionActive, let end = groupStore.sessionEnd, Date() >= end else { return }
        if groupStore.sessionIsScheduled {
            CheatBudgetTracker.endScheduledFocusCheatIfNeeded(sessionEnd: end)
            stopAllCheatExpirySchedules()
        }
        if !groupStore.sessionIsScheduled {
            center.stopMonitoring([activityName])
        }
        if let start = groupStore.sessionStart {
            groupStore.totalFocusSeconds += end.timeIntervalSince(start)
            groupStore.completedSessions += 1
            DailyFocusLog.logSession(start: start, end: end)
        }
        ShieldApplicator.clearShields()
        groupStore.clearSessionMetadata()
        isSessionActive = false
        isScheduledSession = false
        scheduledBlockId = nil
        sessionEndsAt = nil
        plannedDuration = 0
        syncCheatState()
        restartLiveActivityForCurrentMode()
        AchievementTracker.evaluateAndUnlock()
        CloudPreferencesSync.schedulePushDebounced()
    }


    private func restartLiveActivityForCurrentMode() {
        if isCheatActive {
            let cheatEnd = Date().addingTimeInterval(cheatRemainingSeconds)
            LiveActivityManager.startCheatTimer(endsAt: cheatEnd)
            return
        }
        LiveActivityManager.syncToAppState(
            stillModeActive: groupStore.stillModeActive,
            isSessionActive: isSessionActive,
            sessionEndsAt: sessionEndsAt,
            suppressFocusLiveActivity: groupStore.sessionIsScheduled
        )
    }

    var cheatSourceDisplayName: String {
        if cheatSourceMode == "still" { return "Still Mode" }
        if isScheduledSession { return "Scheduled focus" }
        return "Focus Session"
    }

    /// Turning off the schedule toggle in the block editor — used when the user breaks out of a scheduled session early.
    private func disableScheduledBlockForEarlyBreak(blockIdString: String?) {
        guard let blockIdString, let uuid = UUID(uuidString: blockIdString) else { return }
        var blocks = ScheduledBlockStore.load()
        guard let idx = blocks.firstIndex(where: { $0.id == uuid }) else { return }
        blocks[idx].enabled = false
        ScheduledBlockStore.save(blocks)
        ScheduledBlockScheduler.rescheduleAll()
        CloudPreferencesSync.schedulePushDebounced()
    }

    private static func schedule(from start: Date, to end: Date) -> DeviceActivitySchedule {
        let cal = Calendar.current
        let startComponents = cal.dateComponents(
            [.calendar, .year, .month, .day, .hour, .minute, .second],
            from: start
        )
        let endComponents = cal.dateComponents(
            [.calendar, .year, .month, .day, .hour, .minute, .second],
            from: end
        )
        return DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
    }
}
