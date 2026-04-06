import UIKit
import UserNotifications

final class StillAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var alarmCoordinator: AlarmRingingCoordinator?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            await alarmCoordinator?.syncFromDeliveredNotifications()
            if #available(iOS 26.0, *) {
                await alarmCoordinator?.syncFromAlarmKitState()
            }
            alarmCoordinator?.restorePendingIfNeeded()
            alarmCoordinator?.ensureForegroundAlarmSoundIfNeeded()
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Task { @MainActor in
            _ = await alarmCoordinator?.handleOpenURL(url)
        }
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == "STILL_ALARM" {
            deliverAlarm(notification)
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.banner, .sound, .list])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == "STILL_ALARM" {
            deliverAlarm(response.notification)
        }
        completionHandler()
    }

    private func deliverAlarm(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        guard let idStr = info["alarmId"] as? String,
              let uuid = UUID(uuidString: idStr),
              let mode = info["dismissMode"] as? String
        else { return }
        Task { @MainActor in
            alarmCoordinator?.handleNotificationDelivery(
                alarmId: uuid,
                dismissModeRaw: mode,
                fireDate: notification.date
            )
        }
    }
}
