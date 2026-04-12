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

    /// Start/end for this block on the calendar day of `reference` (handles overnight windows).
    func intervalStartEnd(containing reference: Date) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: reference)
        guard weekdays.contains(weekday) else { return nil }

        let dayStart = cal.startOfDay(for: reference)
        let startDate = cal.date(byAdding: .minute, value: startMinute, to: dayStart)!
        let endDate: Date
        if endMinute <= startMinute {
            let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart)!
            endDate = cal.date(byAdding: .minute, value: endMinute, to: nextDayStart)!
        } else {
            endDate = cal.date(byAdding: .minute, value: endMinute, to: dayStart)!
        }
        return (startDate, endDate)
    }

    // MARK: - Overlap (product rule: no two enabled blocks may share time on a shared weekday)

    /// True if the recurring windows can intersect on a shared weekday (ignores `enabled`).
    func recurringTimeOverlap(with other: ScheduledBlock) -> Bool {
        guard id != other.id else { return false }
        let shared = weekdays.intersection(other.weekdays)
        guard !shared.isEmpty else { return false }
        let cal = Calendar.current
        let searchStart = Date().addingTimeInterval(-21 * 86400)
        for wd in shared {
            guard let noon = Self.noon(onWeekday: wd, calendar: cal, searchStart: searchStart) else { continue }
            guard let i1 = intervalStartEnd(containing: noon),
                  let i2 = other.intervalStartEnd(containing: noon) else { continue }
            if i1.start < i2.end && i2.start < i1.end { return true }
        }
        return false
    }

    /// Other **enabled** blocks whose recurring windows overlap this block. Empty if `self` is disabled.
    func enabledTimeOverlaps(in blocks: [ScheduledBlock]) -> [ScheduledBlock] {
        guard enabled else { return [] }
        return blocks.filter { $0.enabled && $0.id != id && recurringTimeOverlap(with: $0) }
    }

    private static func noon(onWeekday wd: Int, calendar cal: Calendar, searchStart: Date) -> Date? {
        var comps = DateComponents()
        comps.calendar = cal
        comps.weekday = wd
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return cal.nextDate(
            after: searchStart,
            matching: comps,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
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
