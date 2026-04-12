import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class StillModeController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var startedAt: Date?
    /// Set when the user scans the QR to exit — triggers the sentence confirmation UI.
    @Published var pendingExit = false
    /// Set when a non-Pro user scans the QR — triggers the paywall sheet.
    @Published var showProPaywall = false

    private let groupStore = AppGroupStore.shared

    init() {
        syncFromStore()
    }

    func syncFromStore() {
        groupStore.synchronizeForCrossProcessRead()
        isActive = groupStore.stillModeActive
        startedAt = groupStore.stillModeStart
    }

    var elapsedSeconds: TimeInterval {
        guard let start = startedAt else { return 0 }
        return max(0, Date().timeIntervalSince(start))
    }

    // MARK: - Activation

    func activate() {
        guard !isActive else { return }
        guard !groupStore.sessionIsScheduled else { return }
        guard !groupStore.sessionActive else { return }
        guard let data = groupStore.stillModeSelectionData,
              let selection = try? SelectionCodec.decode(data),
              tokenCount(selection) > 0
        else { return }

        let now = Date()
        groupStore.stillModeActive = true
        groupStore.stillModeStart = now

        ShieldApplicator.applyShields(for: selection)
        LiveActivityManager.startStillModeTimer()

        isActive = true
        startedAt = now
    }

    /// Returns `true` if there are apps selected for Still Mode.
    var hasSelection: Bool {
        guard let data = groupStore.stillModeSelectionData,
              let sel = try? SelectionCodec.decode(data)
        else { return false }
        return tokenCount(sel) > 0
    }

    // MARK: - Deactivation

    func requestExit() {
        pendingExit = true
    }

    /// Validates the typed sentence and deactivates Still Mode.
    func confirmExit(sentence: String) -> Bool {
        let expected = "I am getting out of Still Mode"
        let clean = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.caseInsensitiveCompare(expected) == .orderedSame else { return false }
        StreakTracker.markManualBreak()

        if let start = groupStore.stillModeStart {
            let end = Date()
            groupStore.totalFocusSeconds += end.timeIntervalSince(start)
            groupStore.completedSessions += 1
            DailyFocusLog.logSession(start: start, end: end)
            AchievementTracker.evaluateAndUnlock()
        }

        ShieldApplicator.clearShields()
        LiveActivityManager.stop()
        groupStore.clearStillModeMetadata()

        isActive = false
        startedAt = nil
        pendingExit = false
        CloudPreferencesSync.schedulePushDebounced()
        return true
    }

    func cancelExit() {
        pendingExit = false
    }

    // MARK: - Selection persistence

    func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? SelectionCodec.encode(selection) else { return }
        groupStore.stillModeSelectionData = data
        CloudPreferencesSync.schedulePushDebounced()
    }

    func loadSelection() -> FamilyActivitySelection {
        guard let data = groupStore.stillModeSelectionData,
              let sel = try? SelectionCodec.decode(data)
        else { return FamilyActivitySelection() }
        return sel
    }

    private func tokenCount(_ sel: FamilyActivitySelection) -> Int {
        sel.applicationTokens.count + sel.categoryTokens.count + sel.webDomainTokens.count
    }
}
