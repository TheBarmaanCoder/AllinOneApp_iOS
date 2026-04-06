import UserNotifications

extension UNUserNotificationCenter {
    func deliveredNotificationsAsync() async -> [UNNotification] {
        await withCheckedContinuation { cont in
            getDeliveredNotifications { cont.resume(returning: $0) }
        }
    }
}
