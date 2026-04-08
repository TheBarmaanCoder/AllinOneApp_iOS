import DeviceActivity
import FamilyControls
import Foundation

@objc(DeviceActivityMonitorExtension)
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let scheduledPrefix = "scheduledBlock_"
    private var cheatPrefix: String { AppConstants.cheatDeviceActivityNamePrefix }
    private let activityCenter = DeviceActivityCenter()

    override func intervalDidStart(for activity: DeviceActivityName) {
        if activity.rawValue.hasPrefix(scheduledPrefix) {
            handleScheduledBlockStart(activity)
            return
        }
        if activity.rawValue.hasPrefix(cheatPrefix) {
            return
        }

        guard let data = AppGroupStore.shared.loadSessionSelectionData(),
              let selection = try? SelectionCodec.decode(data)
        else { return }
        ShieldApplicator.applyShields(for: selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        if activity.rawValue.hasPrefix(scheduledPrefix) {
            handleScheduledBlockEnd()
            return
        }
        if activity.rawValue.hasPrefix(cheatPrefix) {
            handleCheatIntervalDidEnd()
            return
        }

        let g = AppGroupStore.shared
        if g.sessionActive, let start = g.sessionStart, let end = g.sessionEnd {
            g.totalFocusSeconds += end.timeIntervalSince(start)
            g.completedSessions += 1
            DailyFocusLog.logSession(start: start, end: end)
            AchievementTracker.evaluateAndUnlock()
        }
        ShieldApplicator.clearShields()
        g.clearSessionMetadata()
    }

    /// Fires shortly before a short (<15 min) cheat interval ends — real cheat expiry for sub‑15‑minute budgets.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        guard activity.rawValue.hasPrefix(cheatPrefix) else { return }
        CheatBudgetTracker.endCheat()
        activityCenter.stopMonitoring([activity])
        reapplyShieldsAfterCheatEnded()
    }

    private func handleCheatIntervalDidEnd() {
        CheatBudgetTracker.endCheat()
        reapplyShieldsAfterCheatEnded()
    }

    private func reapplyShieldsAfterCheatEnded() {
        let g = AppGroupStore.shared

        if g.stillModeActive,
           let data = g.stillModeSelectionData,
           let selection = try? SelectionCodec.decode(data) {
            ShieldApplicator.applyShields(for: selection)
            return
        }

        if g.sessionActive,
           let data = g.loadSessionSelectionData(),
           let selection = try? SelectionCodec.decode(data) {
            ShieldApplicator.applyShields(for: selection)
            return
        }

        ShieldApplicator.clearShields()
    }

    // MARK: - Scheduled blocks

    private func handleScheduledBlockStart(_ activity: DeviceActivityName) {
        let raw = activity.rawValue
        let parts = raw.replacingOccurrences(of: scheduledPrefix, with: "").components(separatedBy: "_")
        guard parts.count >= 5,
              let blockIDStr = parts.dropLast().joined(separator: "_").components(separatedBy: "_").first(where: { _ in true }),
              let _ = UUID(uuidString: String(raw.dropFirst(scheduledPrefix.count).prefix(36)))
        else { return }

        let idStr = String(raw.dropFirst(scheduledPrefix.count).prefix(36))
        guard let blockID = UUID(uuidString: idStr) else { return }

        let key = "scheduledBlockSelection_\(blockID.uuidString)"
        guard let data = UserDefaults(suiteName: AppConstants.appGroupId)?.data(forKey: key),
              let selection = try? SelectionCodec.decode(data)
        else { return }
        ShieldApplicator.applyShields(for: selection)
    }

    private func handleScheduledBlockEnd() {
        let g = AppGroupStore.shared
        guard !g.sessionActive && !g.stillModeActive else { return }
        ShieldApplicator.clearShields()
    }
}
