import Foundation

enum AppConstants {
    static let appGroupId = "group.com.allinoneapp.still"
    static let activityRawName = "com.allinoneapp.still.focus"
    /// Device Activity schedules created when the user taps Cheat on the shield (must match `ShieldActionExtension`).
    static let cheatDeviceActivityNamePrefix = "cheatCountdown_"
    /// Must match the iCloud container in Apple Developer → Identifiers → Still app → iCloud.
    static let cloudKitContainerIdentifier = "iCloud.com.allinoneapp.still"
}
