import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct StillTimerAttributes: ActivityAttributes {
    /// Which mode started this activity.
    enum Mode: String, Codable {
        case focus
        case stillMode
        case cheat
    }

    let mode: Mode
    let label: String

    struct ContentState: Codable, Hashable {
        let startDate: Date
        let endDate: Date?
    }
}
