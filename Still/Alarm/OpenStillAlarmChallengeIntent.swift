import AlarmKit
import AppIntents
import Foundation

/// Runs when the user **slides to dismiss** (stop gesture) on the lock screen.
/// Persists the pending challenge and schedules nag alarms, but does **NOT** open the app.
/// The alarm sound is already silenced by the system at this point.
@available(iOS 26.0, *)
struct OpenStillAlarmChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss Still Alarm"
    static var description: IntentDescription? = IntentDescription(
        "Silences the alarm but schedules follow-up nag alarms until the challenge is completed."
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool { false }

    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() { alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    static var parameterSummary: some ParameterSummary {
        Summary("Alarm \(\.$alarmID)")
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else { return .result() }
        guard !ChallengeCompletionMarker.wasRecentlyCompleted(for: uuid) else {
            await AlarmNagScheduler.cancelAll()
            return .result()
        }
        guard let resolved = Self.resolveOrCreatePendingSession(alarmId: uuid) else { return .result() }

        await AlarmNagScheduler.scheduleNagAlarms(
            originalAlarmId: resolved.session.alarmId,
            dismissMode: resolved.session.dismissMode,
            label: resolved.label,
            ringtoneID: resolved.ringtoneID
        )
        return .result()
    }

    // MARK: - Shared helpers

    struct ResolvedPending {
        let session: PendingAlarmSession
        let label: String
        let ringtoneID: String
    }

    static func resolveOrCreatePendingSession(alarmId: UUID) -> ResolvedPending? {
        let defaults = UserDefaults.standard
        let group = UserDefaults(suiteName: AppConstants.appGroupId)

        if let existing = loadExistingPending(defaults: defaults, group: group),
           existing.alarmId == alarmId, Date() < existing.expires {
            let stored = lookupStoredAlarm(id: alarmId, defaults: defaults, group: group)
            return ResolvedPending(session: existing, label: stored?.label ?? "", ringtoneID: stored?.ringtoneID ?? "default")
        }

        let stored = lookupStoredAlarm(id: alarmId, defaults: defaults, group: group)
        let dismissMode = stored?.dismissMode ?? .simple
        let label = stored?.label ?? ""
        let ringtoneID = stored?.ringtoneID ?? "default"
        let fireDate = Date()
        let expires = Calendar.current.date(byAdding: .hour, value: 2, to: fireDate) ?? fireDate.addingTimeInterval(7200)

        let session = PendingAlarmSession(alarmId: alarmId, dismissMode: dismissMode, fireDate: fireDate, expires: expires)
        guard let data = try? JSONEncoder().encode(session) else { return nil }
        defaults.set(data, forKey: AlarmConstants.pendingSessionKey)
        group?.set(data, forKey: AlarmConstants.pendingSessionAppGroupKey)
        return ResolvedPending(session: session, label: label, ringtoneID: ringtoneID)
    }

    static func loadExistingPending(defaults: UserDefaults, group: UserDefaults?) -> PendingAlarmSession? {
        let candidates: [(UserDefaults?, String)] = [
            (group, AlarmConstants.pendingSessionAppGroupKey),
            (defaults, AlarmConstants.pendingSessionKey),
        ]
        for (suite, key) in candidates {
            guard let suite, let data = suite.data(forKey: key),
                  let p = try? JSONDecoder().decode(PendingAlarmSession.self, from: data) else { continue }
            return p
        }
        return nil
    }

    static func lookupStoredAlarm(id: UUID, defaults: UserDefaults, group: UserDefaults?) -> StoredAlarm? {
        let mirrorData = group?.data(forKey: AlarmConstants.alarmsMirrorKey) ?? defaults.data(forKey: AlarmConstants.alarmsMirrorKey)
        return mirrorData.flatMap { (try? JSONDecoder().decode([StoredAlarm].self, from: $0))?.first { $0.id == id } }
    }
}

/// Separate intent for the **secondary button** ("I'm up" / "Scan QR code").
/// Opens the app AND schedules nag alarms so they keep firing even if the user leaves.
@available(iOS 26.0, *)
struct OpenStillFromAlarmButton: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Still Challenge"
    static var description: IntentDescription? = IntentDescription("Opens Still to complete the alarm challenge.")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool { false }

    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() { alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    static var parameterSummary: some ParameterSummary {
        Summary("Alarm \(\.$alarmID)")
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else { return .result() }
        guard !ChallengeCompletionMarker.wasRecentlyCompleted(for: uuid) else {
            await AlarmNagScheduler.cancelAll()
            return .result()
        }
        // Only create the pending session — the coordinator schedules nags when the app opens.
        // Scheduling nags here too would race with the coordinator and cancel each other's nags.
        _ = OpenStillAlarmChallengeIntent.resolveOrCreatePendingSession(alarmId: uuid)
        return .result()
    }
}
