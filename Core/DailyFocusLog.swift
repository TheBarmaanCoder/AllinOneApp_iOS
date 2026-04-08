import Foundation

/// Tracks per-day focus seconds in a JSON dictionary keyed by "yyyy-MM-dd".
/// Stored in the shared App Group so both the app and extensions can log time.
enum DailyFocusLog {
    private static let storageKey = "stillDailyFocusLog"
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    // MARK: - Read

    static func loadAll() -> [String: TimeInterval] {
        guard let data = defaults?.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data)
        else { return [:] }
        return dict
    }

    static func seconds(for date: Date) -> TimeInterval {
        loadAll()[key(for: date)] ?? 0
    }

    static func todaySeconds() -> TimeInterval {
        seconds(for: Date())
    }

    /// Returns seconds for each day in the given month (1-indexed day → seconds).
    static func monthData(year: Int, month: Int) -> [Int: TimeInterval] {
        let all = loadAll()
        let prefix = String(format: "%04d-%02d", year, month)
        var result: [Int: TimeInterval] = [:]
        for (dateKey, secs) in all where dateKey.hasPrefix(prefix) {
            let dayStr = dateKey.suffix(2)
            if let day = Int(dayStr) {
                result[day] = secs
            }
        }
        return result
    }

    // MARK: - Write

    static func addSeconds(_ seconds: TimeInterval, on date: Date) {
        guard seconds > 0 else { return }
        var dict = loadAll()
        let k = key(for: date)
        dict[k, default: 0] += seconds
        persist(dict)
    }

    /// Log focus time for a session that ran from `start` to `end`.
    /// If the session spans midnight, time is split across days.
    static func logSession(start: Date, end: Date) {
        let cal = Calendar.current
        var cursor = start
        while cursor < end {
            let endOfDay = cal.startOfDay(for: cursor).addingTimeInterval(86400)
            let segmentEnd = min(end, endOfDay)
            let secs = segmentEnd.timeIntervalSince(cursor)
            if secs > 0 {
                addSeconds(secs, on: cursor)
            }
            cursor = segmentEnd
        }
    }

    // MARK: - Persistence

    private static func persist(_ dict: [String: TimeInterval]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        defaults?.set(data, forKey: storageKey)
    }
}
