import Foundation

/// A named recurring block that activates on specific weekdays at a start/end time.
struct ScheduledBlock: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var enabled: Bool
    /// Days of the week (1 = Sunday … 7 = Saturday, matching Calendar.component(.weekday))
    var weekdays: Set<Int>
    /// Start time: hour * 60 + minute
    var startMinute: Int
    /// End time: hour * 60 + minute
    var endMinute: Int
    /// Encoded FamilyActivitySelection
    var selectionData: Data

    var startHour: Int { startMinute / 60 }
    var startMin: Int { startMinute % 60 }
    var endHour: Int { endMinute / 60 }
    var endMin: Int { endMinute % 60 }

    var formattedTime: String {
        let s = String(format: "%d:%02d", startHour, startMin)
        let e = String(format: "%d:%02d", endHour, endMin)
        return "\(s) – \(e)"
    }

    var weekdayAbbreviations: String {
        let abbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().compactMap { d in
            (1...7).contains(d) ? abbrevs[d - 1] : nil
        }.joined(separator: ", ")
    }
}

// MARK: - Storage

enum ScheduledBlockStore {
    private static let key = "stillScheduledBlocks"
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    static func load() -> [ScheduledBlock] {
        guard let data = defaults?.data(forKey: key),
              let blocks = try? JSONDecoder().decode([ScheduledBlock].self, from: data)
        else { return [] }
        return blocks
    }

    static func save(_ blocks: [ScheduledBlock]) {
        guard let data = try? JSONEncoder().encode(blocks) else { return }
        defaults?.set(data, forKey: key)
    }
}
