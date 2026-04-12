import FamilyControls
import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Persists last-known permission state in the app group and detects transitions from granted → revoked
/// so we only prompt when the user likely turned access off in Settings, not on every launch.
enum PermissionRevocationTracker {
    private static var group: UserDefaults? { UserDefaults(suiteName: AppConstants.appGroupId) }

    private enum Keys {
        static let screenTimeLastKnownApproved = "stillPermissionScreenTimeLastKnownApproved"
        static let notificationsLastKnownOK = "stillPermissionNotificationsLastKnownOK"
        static let alarmKitLastKnownAuthorized = "stillPermissionAlarmKitLastKnownAuthorized"
    }

    enum AlarmRevocationKind: Equatable {
        case none
        case alarmKit
        case notifications
    }

    /// Updates the stored Screen Time snapshot. Returns `true` only when status was approved and is no longer approved.
    static func refreshScreenTimeRevocation() -> Bool {
        let current = FocusAuthorization.authorizationStatus() == .approved
        let last = group?.bool(forKey: Keys.screenTimeLastKnownApproved) ?? false
        let revoked = last && !current
        group?.set(current, forKey: Keys.screenTimeLastKnownApproved)
        return revoked
    }

    private static func refreshNotificationRevocation() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let current: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            current = true
        default:
            current = false
        }
        let last = group?.bool(forKey: Keys.notificationsLastKnownOK) ?? false
        let revoked = last && !current
        group?.set(current, forKey: Keys.notificationsLastKnownOK)
        return revoked
    }

    @available(iOS 26.0, *)
    private static func refreshAlarmKitRevocation() -> Bool {
        let current = AlarmManager.shared.authorizationState == .authorized
        let last = group?.bool(forKey: Keys.alarmKitLastKnownAuthorized) ?? false
        let revoked = last && !current
        group?.set(current, forKey: Keys.alarmKitLastKnownAuthorized)
        return revoked
    }

    /// AlarmKit when authorized; otherwise notification authorization (used for alarm delivery on older iOS).
    static func refreshAlarmRelatedRevocation() async -> AlarmRevocationKind {
        if #available(iOS 26.0, *) {
            if refreshAlarmKitRevocation() {
                return .alarmKit
            }
            if AlarmKitScheduler.authorizationState() == .authorized {
                return .none
            }
        }
        if await refreshNotificationRevocation() {
            return .notifications
        }
        return .none
    }
}
