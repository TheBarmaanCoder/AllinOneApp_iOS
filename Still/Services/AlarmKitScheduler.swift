import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

/// Schedules real system alarms via AlarmKit (iOS 26+). Uses the same `UUID` as `StoredAlarm.id`.
@available(iOS 26.0, *)
enum AlarmKitScheduler {
    static func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    static func authorizationState() -> AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    /// Cancels scheduled alarms (but not nag timers), then re-schedules enabled `StoredAlarm` rows.
    static func sync(alarms: [StoredAlarm]) async {
        let nagIds = Set(
            UserDefaults.standard.stringArray(forKey: AlarmConstants.nagAlarmIdsKey) ?? []
        )
        do {
            let existing = try AlarmManager.shared.alarms
            for a in existing where !nagIds.contains(a.id.uuidString) {
                try? AlarmManager.shared.cancel(id: a.id)
            }
        } catch {}

        for alarm in alarms where alarm.isEnabled && !alarm.weekdays.isEmpty {
            do {
                try await schedule(alarm)
            } catch {}
        }
    }

    private static func schedule(_ alarm: StoredAlarm) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence =
            alarm.weekdays.isEmpty ? .never : .weekly(localeWeekdays(alarm.weekdays))
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))

        let title: LocalizedStringResource = switch alarm.dismissMode.normalized {
        case .qr:
            alarm.label.isEmpty
                ? LocalizedStringResource(stringLiteral: "Alarm")
                : LocalizedStringResource(stringLiteral: alarm.label)
        default:
            alarm.label.isEmpty
                ? LocalizedStringResource(stringLiteral: "Alarm — Still")
                : LocalizedStringResource(stringLiteral: alarm.label)
        }

        let openButton = openChallengeAlarmButton(for: alarm)
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
                    text: LocalizedStringResource("Stop"),
                    textColor: .white,
                    systemImageName: "stop.circle"
                ),
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        }
        let metadata = StillAlarmMetadata(dismissMode: alarm.dismissMode.rawValue, label: alarm.label)
        let attributes = AlarmAttributes<StillAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: Color(red: 0.42, green: 0.48, blue: 0.58)
        )

        let sound = alertSound(for: alarm.ringtoneID)
        let alarmIDString = alarm.id.uuidString
        let stopIntent = OpenStillAlarmChallengeIntent(alarmID: alarmIDString)
        let openFromButtonIntent = OpenStillFromAlarmButton(alarmID: alarmIDString)
        let configuration = AlarmManager.AlarmConfiguration<StillAlarmMetadata>.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: openFromButtonIntent,
            sound: sound
        )
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
    }

    /// Shown above the system stop control; runs `secondaryIntent` (same as slide/stop: open app + pending challenge).
    private static func openChallengeAlarmButton(for alarm: StoredAlarm) -> AlarmButton {
        switch alarm.dismissMode.normalized {
        case .qr:
            return AlarmButton(
                text: LocalizedStringResource(stringLiteral: "Scan QR code"),
                textColor: .white,
                systemImageName: "qrcode.viewfinder"
            )
        default:
            return AlarmButton(
                text: LocalizedStringResource(stringLiteral: "I'm up"),
                textColor: .white,
                systemImageName: "sunrise"
            )
        }
    }

    private static func localeWeekdays(_ weekdays: Set<Int>) -> [Locale.Weekday] {
        let pairs: [(Int, Locale.Weekday)] = [
            (1, .sunday), (2, .monday), (3, .tuesday), (4, .wednesday),
            (5, .thursday), (6, .friday), (7, .saturday),
        ]
        return pairs.filter { weekdays.contains($0.0) }.map(\.1)
    }

    static func alertSound(for ringtoneID: String) -> AlertConfiguration.AlertSound {
        switch ringtoneID {
        case "default", "":
            return .default
        case "still_glass":
            return .named("still_glass")
        case "still_ping":
            return .named("still_ping")
        case "still_tink":
            return .named("still_tink")
        default:
            return .default
        }
    }
}
