import DeviceActivity
import FamilyControls
import Foundation

/// Starts an app-group “focus session” when a scheduled block interval begins (used by `DeviceActivityMonitorExtension`).
enum ScheduledSessionStarter {
    static func startIfPossible(activityRawValue: String, scheduledPrefix: String) {
        let raw = activityRawValue
        guard raw.hasPrefix(scheduledPrefix) else { return }

        let body = String(raw.dropFirst(scheduledPrefix.count))
        guard let lastUnderscore = body.lastIndex(of: "_") else { return }
        let idStr = String(body[..<lastUnderscore])
        guard let blockID = UUID(uuidString: idStr) else { return }

        let g = AppGroupStore.shared
        if g.stillModeActive { return }
        if g.sessionActive, !g.sessionIsScheduled { return }

        let blocks = ScheduledBlockStore.load()
        guard let block = blocks.first(where: { $0.id == blockID && $0.enabled }) else { return }

        let now = Date()
        guard let interval = block.intervalStartEnd(containing: now) else { return }
        guard now >= interval.start, now < interval.end else { return }

        guard let selection = try? SelectionCodec.decode(block.selectionData) else { return }
        guard let data = try? SelectionCodec.encode(selection) else { return }

        g.persistSessionSelection(data)
        // Count only from when this session actually begins (now), not the calendar window start —
        // otherwise joining late credits hours before the user was in a block.
        g.sessionStart = now
        g.sessionEnd = interval.end
        g.sessionActive = true
        g.sessionIsScheduled = true
        g.scheduledBlockSessionId = block.id.uuidString
        g.synchronizeForCrossProcessRead()

        ShieldApplicator.applyShields(for: selection)
    }

    /// Finalize scheduled session at interval end (same accounting as natural focus end).
    static func endScheduledSessionIfNeeded() {
        let g = AppGroupStore.shared
        guard g.sessionActive, g.sessionIsScheduled,
              let start = g.sessionStart,
              let end = g.sessionEnd
        else { return }

        CheatBudgetTracker.endScheduledFocusCheatIfNeeded(sessionEnd: end)
        stopCheatExpiryMonitoringIfNeeded()

        g.totalFocusSeconds += end.timeIntervalSince(start)
        g.completedSessions += 1
        DailyFocusLog.logSession(start: start, end: end)
        AchievementTracker.evaluateAndUnlock()
        ShieldApplicator.clearShields()
        g.clearSessionMetadata()
    }

    private static func stopCheatExpiryMonitoringIfNeeded() {
        let prefix = AppConstants.cheatDeviceActivityNamePrefix
        let center = DeviceActivityCenter()
        let names = center.activities.filter { $0.rawValue.hasPrefix(prefix) }
        if !names.isEmpty {
            center.stopMonitoring(names)
        }
    }
}
