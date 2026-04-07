import Foundation
import UserNotifications

/// Local notification scheduling (iOS 16+). One repeating trigger per alarm × weekday.
enum AlarmScheduler {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    static func removeAllPendingRequests() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func rescheduleAll(alarms: [StoredAlarm]) async {
        let center = UNUserNotificationCenter.current()
        removeAllPendingRequests()

        for alarm in alarms {
            guard alarm.isEnabled, !alarm.weekdays.isEmpty else { continue }
            for weekday in alarm.weekdays {
                let id = "\(alarm.id.uuidString)-w\(weekday)"
                let content = UNMutableNotificationContent()
                content.title = notificationTitle(for: alarm)
                content.body = alarm.label.isEmpty ? "Still" : alarm.label
                content.sound = .default
                content.userInfo = [
                    "alarmId": alarm.id.uuidString,
                    "dismissMode": alarm.dismissMode.rawValue,
                ]
                content.categoryIdentifier = "STILL_ALARM"

                var dc = DateComponents()
                dc.weekday = weekday
                dc.hour = alarm.hour
                dc.minute = alarm.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    private static func notificationTitle(for alarm: StoredAlarm) -> String {
        switch alarm.dismissMode.normalized {
        case .qr:
            return alarm.label.isEmpty ? "Alarm" : alarm.label
        default:
            return alarm.label.isEmpty ? "Alarm — Still" : alarm.label
        }
    }
}
