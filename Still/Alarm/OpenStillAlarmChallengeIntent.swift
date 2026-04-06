import AlarmKit
import AppIntents
import Foundation

/// Runs when the user taps Stop on the system alarm UI. Opens Still and hands off to the in-app walk / QR flow.
@available(iOS 26.0, *)
struct OpenStillAlarmChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Still"
    static var description: IntentDescription? = IntentDescription(
        "Opens Still so you can finish dismissing your alarm."
    )
    static var openAppWhenRun: Bool = true

    static var isDiscoverable: Bool { false }

    static var supportedModes: IntentModes {
        [.foreground(.dynamic), .background]
    }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Alarm \(\.$alarmID)")
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            return .result()
        }
        Self.persistPendingSession(alarmKitId: uuid)
        try? AlarmManager.shared.stop(id: uuid)
        return .result()
    }

    private static func persistPendingSession(alarmKitId uuid: UUID) {
        let defaults = UserDefaults.standard
        let group = UserDefaults(suiteName: AppConstants.appGroupId)
        let mirrorData = group?.data(forKey: AlarmConstants.alarmsMirrorKey)
            ?? defaults.data(forKey: AlarmConstants.alarmsMirrorKey)
        let stored: StoredAlarm? = mirrorData.flatMap { data in
            (try? JSONDecoder().decode([StoredAlarm].self, from: data))?.first { $0.id == uuid }
        }
        let dismissMode = stored?.dismissMode ?? .walk
        let fireDate = Date()
        let expires = Calendar.current.date(byAdding: .hour, value: 2, to: fireDate)
            ?? fireDate.addingTimeInterval(7200)
        let session = PendingAlarmSession(
            alarmId: uuid,
            dismissMode: dismissMode,
            fireDate: fireDate,
            expires: expires
        )
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: AlarmConstants.pendingSessionKey)
        group?.set(data, forKey: AlarmConstants.pendingSessionAppGroupKey)
    }
}
