import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class FocusSessionController: ObservableObject {
    @Published private(set) var isSessionActive = false
    @Published private(set) var sessionEndsAt: Date?
    @Published private(set) var plannedDuration: TimeInterval = 0

    private let groupStore = AppGroupStore.shared
    private let activityName = DeviceActivityName(AppConstants.activityRawName)
    private let center = DeviceActivityCenter()

    init() {
        syncFromStore()
    }

    func syncFromStore() {
        isSessionActive = groupStore.sessionActive
        sessionEndsAt = groupStore.sessionEnd
        if let start = groupStore.sessionStart, let end = groupStore.sessionEnd {
            plannedDuration = end.timeIntervalSince(start)
        }
    }

    /// Starts focus for the merged selection. Persists selection for the monitor extension.
    func startFocus(durationMinutes: Int, selection: FamilyActivitySelection) throws {
        guard durationMinutes > 0 else { return }

        let data = try SelectionCodec.encode(selection)
        groupStore.persistSessionSelection(data)

        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        groupStore.sessionStart = now
        groupStore.sessionEnd = end
        groupStore.sessionActive = true

        plannedDuration = end.timeIntervalSince(now)
        isSessionActive = true
        sessionEndsAt = end

        center.stopMonitoring([activityName])

        let schedule = Self.schedule(from: now, to: end)
        try center.startMonitoring(activityName, during: schedule)

        ShieldApplicator.applyShields(for: selection)
    }

    /// Ends focus early: stops monitoring and clears shields. Counts elapsed time only (not the full plan).
    func breakFocusEarly() {
        center.stopMonitoring([activityName])
        ShieldApplicator.clearShields()
        if let start = groupStore.sessionStart {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0 {
                groupStore.totalFocusSeconds += elapsed
            }
        }
        groupStore.clearSessionMetadata()
        isSessionActive = false
        sessionEndsAt = nil
        plannedDuration = 0
    }

    /// Backup when the monitor extension has not run yet (e.g. Simulator): same accounting as `intervalDidEnd`.
    func completeNaturallyIfNeeded() {
        guard groupStore.sessionActive, let end = groupStore.sessionEnd, Date() >= end else { return }
        center.stopMonitoring([activityName])
        if let start = groupStore.sessionStart {
            groupStore.totalFocusSeconds += end.timeIntervalSince(start)
            groupStore.completedSessions += 1
        }
        ShieldApplicator.clearShields()
        groupStore.clearSessionMetadata()
        isSessionActive = false
        sessionEndsAt = nil
        plannedDuration = 0
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
