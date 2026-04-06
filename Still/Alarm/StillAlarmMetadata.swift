import AlarmKit
import Foundation

/// Metadata attached to AlarmKit schedules (available on iOS 26+).
struct StillAlarmMetadata: AlarmMetadata {
    var dismissMode: String
    var label: String
}
