import Foundation

enum StillAlarmRingtoneOption: String, CaseIterable, Identifiable {
    case `default`
    case still_glass
    case still_ping
    case still_tink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: return "System default"
        case .still_glass: return "Glass"
        case .still_ping: return "Ping"
        case .still_tink: return "Tink"
        }
    }

    var storageID: String { rawValue }
}

enum AlarmDismissMode: String, Codable, CaseIterable, Identifiable {
    case qr
    case walk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qr: return "Scan QR sticker"
        case .walk: return "Walk 15 steps"
        }
    }

    var detail: String {
        switch self {
        case .qr: return "Print your code and scan it to stop."
        case .walk: return "Fifteen steps since the alarm, counted by your iPhone."
        }
    }
}

struct StoredAlarm: Codable, Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    /// `Calendar` weekday: 1 = Sunday … 7 = Saturday
    var weekdays: Set<Int>
    var isEnabled: Bool
    var dismissMode: AlarmDismissMode
    /// `default`, `still_glass`, `still_ping`, or `still_tink` (bundled tones on iOS 26+ AlarmKit).
    var ringtoneID: String

    static let weekdaySymbolsShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    enum CodingKeys: String, CodingKey {
        case id, hour, minute, label, weekdays, isEnabled, dismissMode, ringtoneID
    }

    init(
        id: UUID,
        hour: Int,
        minute: Int,
        label: String,
        weekdays: Set<Int>,
        isEnabled: Bool,
        dismissMode: AlarmDismissMode,
        ringtoneID: String = "default"
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.dismissMode = dismissMode
        self.ringtoneID = ringtoneID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        label = try c.decode(String.self, forKey: .label)
        weekdays = try c.decode(Set<Int>.self, forKey: .weekdays)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        dismissMode = try c.decode(AlarmDismissMode.self, forKey: .dismissMode)
        ringtoneID = try c.decodeIfPresent(String.self, forKey: .ringtoneID) ?? "default"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(hour, forKey: .hour)
        try c.encode(minute, forKey: .minute)
        try c.encode(label, forKey: .label)
        try c.encode(weekdays, forKey: .weekdays)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(dismissMode, forKey: .dismissMode)
        try c.encode(ringtoneID, forKey: .ringtoneID)
    }
}

struct PendingAlarmSession: Codable, Equatable {
    var alarmId: UUID
    var dismissMode: AlarmDismissMode
    var fireDate: Date
    var expires: Date
}

enum AlarmConstants {
    static let requiredSteps = 15
    static let qrURLScheme = "still"
    static let pendingSessionKey = "pendingAlarmSession"
    static let pendingSessionAppGroupKey = "pendingAlarmSessionAppGroup"
    static let alarmsStorageKey = "storedAlarms.v1"
    static let alarmsMirrorKey = "storedAlarmsMirror.v1"
}
