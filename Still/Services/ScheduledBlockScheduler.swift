import DeviceActivity
import FamilyControls
import Foundation

/// Registers DeviceActivity monitoring schedules for each active ScheduledBlock.
/// Each block gets one DeviceActivity name per weekday it's active.
enum ScheduledBlockScheduler {
    private static let center = DeviceActivityCenter()
    private static let prefix = "scheduledBlock_"

    static func rescheduleAll() {
        clearAll()
        let blocks = ScheduledBlockStore.load()
        for block in blocks where block.enabled {
            schedule(block)
        }
    }

    static func clearAll() {
        let existing = center.activities
        let toStop = existing.filter { $0.rawValue.hasPrefix(prefix) }
        if !toStop.isEmpty {
            center.stopMonitoring(toStop)
        }
    }

    private static func schedule(_ block: ScheduledBlock) {
        guard let selection = try? SelectionCodec.decode(block.selectionData) else { return }

        for weekday in block.weekdays {
            let activityName = DeviceActivityName("\(prefix)\(block.id.uuidString)_\(weekday)")

            var startComps = DateComponents()
            startComps.hour = block.startHour
            startComps.minute = block.startMin
            startComps.weekday = weekday

            var endComps = DateComponents()
            endComps.hour = block.endHour
            endComps.minute = block.endMin
            endComps.weekday = weekday

            let schedule = DeviceActivitySchedule(
                intervalStart: startComps,
                intervalEnd: endComps,
                repeats: true
            )

            do {
                try center.startMonitoring(activityName, during: schedule)
            } catch {
                // Silently fail — can't schedule on Simulator etc.
            }
        }

        persistSelectionForBlock(block.id, selection: selection)
    }

    /// Store selection per block so the monitor extension can apply shields.
    private static func persistSelectionForBlock(_ id: UUID, selection: FamilyActivitySelection) {
        guard let data = try? SelectionCodec.encode(selection) else { return }
        let key = "scheduledBlockSelection_\(id.uuidString)"
        UserDefaults(suiteName: AppConstants.appGroupId)?.set(data, forKey: key)
    }

    static func loadSelectionForBlock(_ id: UUID) -> FamilyActivitySelection? {
        let key = "scheduledBlockSelection_\(id.uuidString)"
        guard let data = UserDefaults(suiteName: AppConstants.appGroupId)?.data(forKey: key) else { return nil }
        return try? SelectionCodec.decode(data)
    }
}
