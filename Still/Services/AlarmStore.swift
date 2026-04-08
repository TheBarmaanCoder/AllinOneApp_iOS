import Combine
import Foundation

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [StoredAlarm] = []

    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: AlarmConstants.alarmsStorageKey),
              let decoded = try? JSONDecoder().decode([StoredAlarm].self, from: data)
        else {
            alarms = []
            return
        }
        alarms = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(alarms) {
            defaults.set(data, forKey: AlarmConstants.alarmsStorageKey)
        }
        CloudPreferencesSync.schedulePushDebounced()
    }

    func add(_ alarm: StoredAlarm) {
        alarms.append(alarm)
        persist()
        Task { await AlarmBootstrap.rescheduleAll(alarms: alarms) }
    }

    func update(_ alarm: StoredAlarm) {
        guard let i = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[i] = alarm
        persist()
        Task { await AlarmBootstrap.rescheduleAll(alarms: alarms) }
    }

    func delete(id: UUID) {
        alarms.removeAll { $0.id == id }
        persist()
        Task { await AlarmBootstrap.rescheduleAll(alarms: alarms) }
    }

    func alarm(id: UUID) -> StoredAlarm? {
        alarms.first { $0.id == id }
    }
}
