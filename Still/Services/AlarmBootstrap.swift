import Foundation

/// Chooses AlarmKit (iOS 26+, authorized) or local notifications, and keeps an app-group mirror for alarm intents.
enum AlarmBootstrap {
    static func mirrorAlarmsToSharedDefaults(_ alarms: [StoredAlarm]) {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: AlarmConstants.alarmsMirrorKey)
        UserDefaults(suiteName: AppConstants.appGroupId)?.set(data, forKey: AlarmConstants.alarmsMirrorKey)
    }

    static func rescheduleAll(alarms: [StoredAlarm]) async {
        mirrorAlarmsToSharedDefaults(alarms)

        if #available(iOS 26.0, *) {
            if AlarmKitScheduler.authorizationState() == .authorized {
                await AlarmKitScheduler.sync(alarms: alarms)
                AlarmScheduler.removeAllPendingRequests()
                return
            }
        }

        AlarmScheduler.rescheduleAll(alarms: alarms)
    }

    static var usesAlarmKitThisDevice: Bool {
        if #available(iOS 26.0, *) {
            return AlarmKitScheduler.authorizationState() == .authorized
        }
        return false
    }
}
