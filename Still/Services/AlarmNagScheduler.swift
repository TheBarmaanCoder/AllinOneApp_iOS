import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

/// Schedules real AlarmKit **timer** alarms at 30s intervals after the user dismisses the primary alarm.
/// These ring through DND/Sleep Focus exactly like the original alarm; local notifications cannot do that.
/// The chain continues until the user completes the walk/QR challenge (which calls `cancelAll()`).
@available(iOS 26.0, *)
enum AlarmNagScheduler {
    private static let interval: TimeInterval = 30
    private static let maxNags = 20

    private static var defaults: UserDefaults { .standard }
    private static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    // MARK: - Public

    /// Pre-schedule a batch of timer alarms at 30s, 60s, 90s, … from now.
    /// Each nag's stop/secondary intent re-opens Still with the pending challenge.
    static func scheduleNagAlarms(
        originalAlarmId: UUID,
        dismissMode: AlarmDismissMode,
        label: String,
        ringtoneID: String
    ) async {
        await cancelAll()
        guard AlarmManager.shared.authorizationState == .authorized else { return }

        var ids: [String] = []

        for i in 1...maxNags {
            let nagId = UUID()
            ids.append(nagId.uuidString)
            let duration = interval * Double(i)
            do {
                let config = nagConfiguration(
                    originalAlarmId: originalAlarmId,
                    dismissMode: dismissMode,
                    label: label,
                    ringtoneID: ringtoneID,
                    duration: duration
                )
                _ = try await AlarmManager.shared.schedule(id: nagId, configuration: config)
            } catch {
                break
            }
        }

        saveNagIds(ids)
    }

    /// Cancel every pending nag alarm AND stop any that are already alerting, then clear persisted IDs.
    static func cancelAll() async {
        let ids = loadNagIds()
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        for idStr in ids {
            guard let id = UUID(uuidString: idStr) else { continue }
            try? AlarmManager.shared.stop(id: id)
            try? AlarmManager.shared.cancel(id: id)
        }
        // Also sweep any nag that the system reports (belt-and-suspenders)
        if let all = try? AlarmManager.shared.alarms {
            for alarm in all where idSet.contains(alarm.id.uuidString) {
                try? AlarmManager.shared.stop(id: alarm.id)
                try? AlarmManager.shared.cancel(id: alarm.id)
            }
        }
        clearNagIds()
    }

    // MARK: - Configuration

    private static func nagConfiguration(
        originalAlarmId: UUID,
        dismissMode: AlarmDismissMode,
        label: String,
        ringtoneID: String,
        duration: TimeInterval
    ) -> AlarmManager.AlarmConfiguration<StillAlarmMetadata> {
        let title: LocalizedStringResource = switch dismissMode.normalized {
        case .qr:
            label.isEmpty
                ? LocalizedStringResource(stringLiteral: "Still — scan QR to dismiss")
                : LocalizedStringResource(stringLiteral: label)
        default:
            LocalizedStringResource(stringLiteral: "Still — open app to dismiss")
        }

        let openButton: AlarmButton = switch dismissMode.normalized {
        case .qr:
            AlarmButton(
                text: LocalizedStringResource(stringLiteral: "Scan QR code"),
                textColor: .white,
                systemImageName: "qrcode.viewfinder"
            )
        default:
            AlarmButton(
                text: LocalizedStringResource(stringLiteral: "I'm up"),
                textColor: .white,
                systemImageName: "sunrise"
            )
        }

        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(
                    text: LocalizedStringResource("Snooze"),
                    textColor: .white,
                    systemImageName: "zzz"
                ),
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        }

        let metadata = StillAlarmMetadata(dismissMode: dismissMode.rawValue, label: label)
        let attributes = AlarmAttributes<StillAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: Color(red: 0.42, green: 0.48, blue: 0.58)
        )

        let sound = AlarmKitScheduler.alertSound(for: ringtoneID)
        let alarmIDString = originalAlarmId.uuidString
        let stopIntent = OpenStillAlarmChallengeIntent(alarmID: alarmIDString)
        let openIntent = OpenStillFromAlarmButton(alarmID: alarmIDString)

        return .timer(
            duration: duration,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: openIntent,
            sound: sound
        )
    }

    // MARK: - Persistence

    private static func saveNagIds(_ ids: [String]) {
        defaults.set(ids, forKey: AlarmConstants.nagAlarmIdsKey)
        groupDefaults?.set(ids, forKey: AlarmConstants.nagAlarmIdsKey)
    }

    private static func loadNagIds() -> [String] {
        groupDefaults?.stringArray(forKey: AlarmConstants.nagAlarmIdsKey)
            ?? defaults.stringArray(forKey: AlarmConstants.nagAlarmIdsKey)
            ?? []
    }

    private static func clearNagIds() {
        defaults.removeObject(forKey: AlarmConstants.nagAlarmIdsKey)
        groupDefaults?.removeObject(forKey: AlarmConstants.nagAlarmIdsKey)
    }
}
