import AlarmKit
import Foundation
import SwiftUI
import UserNotifications

struct ActiveAlarmContext: Identifiable, Equatable {
    var id: UUID { alarm.id }
    let alarm: StoredAlarm
    let fireDate: Date
}

@MainActor
final class AlarmRingingCoordinator: ObservableObject {
    @Published var activeRinging: ActiveAlarmContext?
    /// Non-nil while the success animation is playing inside the fullScreenCover.
    @Published var successDismissMode: AlarmDismissMode?

    private let soundPlayer = AlarmSoundPlayer()
    private var alarmStore: AlarmStore?

    private var defaults: UserDefaults { .standard }
    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    func configure(store: AlarmStore) {
        alarmStore = store
        Task { @MainActor in
            await syncFromDeliveredNotifications()
            if #available(iOS 26.0, *) {
                await syncFromAlarmKitState()
            }
            restorePendingIfNeeded()
            ensureForegroundAlarmSoundIfNeeded()
        }
    }

    func restorePendingAndForegroundAudioIfNeeded() {
        guard successDismissMode == nil else { return }
        restorePendingIfNeeded()
        ensureForegroundAlarmSoundIfNeeded()
    }

    func rescheduleNagsIfChallengePending() async {
        guard let pending = loadPending(),
              !ChallengeCompletionMarker.wasRecentlyCompleted(for: pending.alarmId),
              let store = alarmStore,
              let alarm = store.alarm(id: pending.alarmId),
              Date() < pending.expires
        else { return }
        if #available(iOS 26.0, *) {
            await AlarmNagScheduler.scheduleNagAlarms(
                originalAlarmId: alarm.id,
                dismissMode: pending.dismissMode,
                label: alarm.label,
                ringtoneID: alarm.ringtoneID
            )
        }
    }

    // MARK: - Pending session persistence

    private func savePending(_ session: PendingAlarmSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: AlarmConstants.pendingSessionKey)
        appGroupDefaults?.set(data, forKey: AlarmConstants.pendingSessionAppGroupKey)
    }

    private func clearPending() {
        defaults.removeObject(forKey: AlarmConstants.pendingSessionKey)
        appGroupDefaults?.removeObject(forKey: AlarmConstants.pendingSessionAppGroupKey)
    }

    private func loadPending() -> PendingAlarmSession? {
        let candidates: [(UserDefaults?, String)] = [
            (appGroupDefaults, AlarmConstants.pendingSessionAppGroupKey),
            (defaults, AlarmConstants.pendingSessionKey),
        ]
        for (suite, key) in candidates {
            guard let suite, let data = suite.data(forKey: key),
                  let p = try? JSONDecoder().decode(PendingAlarmSession.self, from: data)
            else { continue }
            if Date() >= p.expires {
                clearPending()
                return nil
            }
            return p
        }
        return nil
    }

    // MARK: - Sync from system state

    func syncFromDeliveredNotifications() async {
        guard activeRinging == nil, successDismissMode == nil else { return }
        let items = await UNUserNotificationCenter.current().deliveredNotificationsAsync()
        let relevant = items.filter {
            $0.request.content.categoryIdentifier == "STILL_ALARM"
                && Date().timeIntervalSince($0.date) < 3 * 3600
        }
        guard let latest = relevant.max(by: { $0.date < $1.date }) else { return }
        let info = latest.request.content.userInfo
        guard let idStr = info["alarmId"] as? String,
              let uuid = UUID(uuidString: idStr),
              let mode = info["dismissMode"] as? String,
              !ChallengeCompletionMarker.wasRecentlyCompleted(for: uuid)
        else { return }
        activateAlarmChallenge(alarmId: uuid, dismissModeRaw: mode, fireDate: latest.date, startLocalSound: true)
    }

    @available(iOS 26.0, *)
    func syncFromAlarmKitState() async {
        guard activeRinging == nil, successDismissMode == nil else { return }
        guard let kitAlarms = try? AlarmManager.shared.alarms,
              let alerting = kitAlarms.first(where: { $0.state == .alerting }),
              !ChallengeCompletionMarker.wasRecentlyCompleted(for: alerting.id)
        else { return }
        guard let store = alarmStore,
              let alarm = store.alarm(id: alerting.id),
              alarm.isEnabled else { return }
        activateAlarmChallenge(
            alarmId: alerting.id,
            dismissModeRaw: alarm.dismissMode.rawValue,
            fireDate: Date(),
            startLocalSound: false
        )
    }

    @available(iOS 26.0, *)
    func observeAlarmKitUpdates() async {
        for await updated in AlarmManager.shared.alarmUpdates {
            await MainActor.run {
                guard successDismissMode == nil else { return }
                guard let alerting = updated.first(where: { $0.state == .alerting }),
                      !ChallengeCompletionMarker.wasRecentlyCompleted(for: alerting.id)
                else { return }
                guard let store = alarmStore,
                      let alarm = store.alarm(id: alerting.id),
                      alarm.isEnabled else { return }
                activateAlarmChallenge(
                    alarmId: alerting.id,
                    dismissModeRaw: alarm.dismissMode.rawValue,
                    fireDate: Date(),
                    startLocalSound: false
                )
            }
        }
    }

    func restorePendingIfNeeded() {
        guard successDismissMode == nil else { return }
        guard let pending = loadPending(),
              !ChallengeCompletionMarker.wasRecentlyCompleted(for: pending.alarmId),
              let store = alarmStore,
              let alarm = store.alarm(id: pending.alarmId)
        else { return }
        guard activeRinging == nil else { return }
        activeRinging = ActiveAlarmContext(alarm: alarm, fireDate: pending.fireDate)
        ensureForegroundAlarmSoundIfNeeded()
        scheduleChallengeNags(alarm: alarm, expires: pending.expires)
    }

    func ensureForegroundAlarmSoundIfNeeded() {
        guard activeRinging != nil, successDismissMode == nil else { return }
        if #available(iOS 26.0, *) {
            if anyKitAlarmAlerting() { return }
        }
        if !soundPlayer.isRunning {
            soundPlayer.start()
        }
    }

    @available(iOS 26.0, *)
    private func anyKitAlarmAlerting() -> Bool {
        (try? AlarmManager.shared.alarms.contains { $0.state == .alerting }) ?? false
    }

    private func activateAlarmChallenge(alarmId: UUID, dismissModeRaw: String, fireDate: Date, startLocalSound: Bool) {
        guard successDismissMode == nil,
              !ChallengeCompletionMarker.wasRecentlyCompleted(for: alarmId)
        else { return }
        guard let store = alarmStore,
              let alarm = store.alarm(id: alarmId),
              alarm.isEnabled else { return }
        guard activeRinging == nil else { return }
        let expires = Calendar.current.date(byAdding: .hour, value: 2, to: fireDate) ?? fireDate.addingTimeInterval(7200)
        let session = PendingAlarmSession(
            alarmId: alarmId,
            dismissMode: AlarmDismissMode(rawValue: dismissModeRaw) ?? .simple,
            fireDate: fireDate,
            expires: expires
        )
        savePending(session)
        activeRinging = ActiveAlarmContext(alarm: alarm, fireDate: fireDate)
        if startLocalSound {
            soundPlayer.start()
        }
        scheduleChallengeNags(alarm: alarm, expires: expires)
    }

    private func scheduleChallengeNags(alarm: StoredAlarm, expires: Date) {
        Task {
            if #available(iOS 26.0, *) {
                await AlarmNagScheduler.scheduleNagAlarms(
                    originalAlarmId: alarm.id,
                    dismissMode: alarm.dismissMode,
                    label: alarm.label,
                    ringtoneID: alarm.ringtoneID
                )
            }
        }
    }

    func handleNotificationDelivery(alarmId: UUID, dismissModeRaw: String, fireDate: Date) {
        activateAlarmChallenge(alarmId: alarmId, dismissModeRaw: dismissModeRaw, fireDate: fireDate, startLocalSound: true)
    }

    // MARK: - Challenge completion

    func completeChallengeSuccessfully() {
        guard successDismissMode == nil else { return }
        let mode = activeRinging?.alarm.dismissMode ?? loadPending().map { $0.dismissMode }
        let alarmId = activeRinging?.alarm.id ?? loadPending()?.alarmId

        // 1. Mark THIS alarm as completed
        if let alarmId {
            ChallengeCompletionMarker.markCompleted(alarmId: alarmId)
        }

        // 2. Stop all noise
        soundPlayer.stop()

        // 3. Clear persisted pending session
        clearPending()

        // 4. Cancel all nag alarms + stop the AlarmKit alarm
        if let alarmId {
            Task {
                if #available(iOS 26.0, *) {
                    await AlarmNagScheduler.cancelAll()
                    try? AlarmManager.shared.stop(id: alarmId)
                }
            }
        }
        removeAlarmDeliveredNotifications()

        // 5. Show success animation (activeRinging stays non-nil so fullScreenCover remains)
        successDismissMode = mode
    }

    func dismissSuccessOverlay() {
        successDismissMode = nil
        activeRinging = nil
    }

    func handleOpenURL(_ url: URL) async -> Bool {
        await syncFromDeliveredNotifications()
        guard url.scheme == AlarmConstants.qrURLScheme,
              url.host == "dismiss",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              AlarmQRTokenStore.matches(token)
        else { return false }

        guard let pending = loadPending(),
              pending.dismissMode == .qr,
              Date() < pending.expires
        else { return false }

        completeChallengeSuccessfully()
        return true
    }

    func validateQRPayload(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == AlarmConstants.qrURLScheme,
              url.host == "dismiss",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              AlarmQRTokenStore.matches(token)
        else { return false }
        guard let pending = loadPending(), pending.dismissMode == .qr, Date() < pending.expires else { return false }
        return true
    }

    func clearRingingAndPending() {
        completeChallengeSuccessfully()
    }

    func handleScannedQRPayload(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return false }
        return await handleOpenURL(url)
    }

    private func removeAlarmDeliveredNotifications() {
        Task {
            let items = await UNUserNotificationCenter.current().deliveredNotificationsAsync()
            let ids = items.filter {
                $0.request.content.categoryIdentifier == "STILL_ALARM"
            }.map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
