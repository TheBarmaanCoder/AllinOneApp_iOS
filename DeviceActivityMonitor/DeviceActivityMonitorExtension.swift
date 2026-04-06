import DeviceActivity
import FamilyControls
import Foundation

@objc(DeviceActivityMonitorExtension)
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        guard let data = AppGroupStore.shared.loadSessionSelectionData(),
              let selection = try? SelectionCodec.decode(data)
        else { return }
        ShieldApplicator.applyShields(for: selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        let g = AppGroupStore.shared
        if g.sessionActive, let start = g.sessionStart, let end = g.sessionEnd {
            g.totalFocusSeconds += end.timeIntervalSince(start)
            g.completedSessions += 1
        }
        ShieldApplicator.clearShields()
        g.clearSessionMetadata()
    }
}
