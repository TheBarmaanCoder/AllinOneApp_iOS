import CloudKit
import Foundation
import os.log

extension Notification.Name {
    /// Posted after remote iCloud preferences were applied (theme, onboarding, alarms, etc.).
    static let stillCloudPreferencesMerged = Notification.Name("stillCloudPreferencesMerged")
    /// App group / cheat / focus state changed — refresh `StillModeController` from the store.
    static let stillModeStoreNeedsSync = Notification.Name("stillModeStoreNeedsSync")
}

/// Syncs user preferences and app data (not live session / shield state) via CloudKit private database.
enum CloudPreferencesSync {
    #if DEBUG
    private static let log = Logger(subsystem: "com.allinoneapp.still", category: "CloudKit")
    #endif

    private static let recordType = "UserPreferences"
    private static let recordName = "userPreferencesSingleton"

    private enum Field {
        static let clientLastModified = "clientLastModified"
        static let stillTheme = "stillTheme"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let alarmsData = "alarmsData"
        static let groupsData = "groupsData"
        static let totalFocusSeconds = "totalFocusSeconds"
        static let completedSessions = "completedSessions"
        static let stillModeSelectionData = "stillModeSelectionData"
        static let stillProUnlocked = "stillProUnlocked"
        static let alarmQRToken = "alarmQRToken"
        static let dailyFocusLog = "dailyFocusLog"
        static let unlockedAchievements = "unlockedAchievements"
    }

    private enum LocalKey {
        static let lastAppliedClientMod = "stillCloudKitLastAppliedClientMod"
    }

    private static var container: CKContainer {
        CKContainer(identifier: AppConstants.cloudKitContainerIdentifier)
    }

    private static var database: CKDatabase {
        container.privateCloudDatabase
    }

    private static var recordID: CKRecord.ID {
        CKRecord.ID(recordName: recordName)
    }

    // MARK: - Public

    static func schedulePushDebounced() {
        PushDebouncer.shared.schedule {
            await pushSnapshot()
        }
    }

    /// Call on launch (before relying on local alarm list) and when returning to foreground.
    static func pullAndMergeIfNeeded() async {
        guard await isCloudAvailable() else {
            #if DEBUG
            log.debug("pull skipped: iCloud account not available")
            #endif
            return
        }

        do {
            let record = try await database.record(for: recordID)
            let cloudMod = (record[Field.clientLastModified] as? Double)
                ?? (record.modificationDate?.timeIntervalSince1970 ?? 0)
            let lastApplied = UserDefaults.standard.double(forKey: LocalKey.lastAppliedClientMod)
            guard cloudMod > lastApplied else {
                #if DEBUG
                log.debug("pull skipped: cloud not newer (cloud=\(cloudMod, privacy: .public) local=\(lastApplied, privacy: .public))")
                #endif
                return
            }

            await MainActor.run {
                mergeRecordIntoLocalStores(record, cloudMod: cloudMod)
            }
            #if DEBUG
            let alarmBytes = (record[Field.alarmsData] as? Data)?.count ?? 0
            log.info("pull merged from iCloud (clientLastModified=\(cloudMod, privacy: .public), alarmsData bytes=\(alarmBytes, privacy: .public))")
            #endif
        } catch let error as CKError where error.code == .unknownItem {
            #if DEBUG
            log.info("no CloudKit record yet — pushing initial snapshot")
            #endif
            await pushSnapshot()
        } catch {
            #if DEBUG
            log.error("pull failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    static func pushSnapshot() async {
        guard await isCloudAvailable() else {
            #if DEBUG
            log.debug("push skipped: iCloud account not available")
            #endif
            return
        }

        let now = Date().timeIntervalSince1970

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        } catch {
            #if DEBUG
            log.error("push aborted (fetch record): \(String(describing: error), privacy: .public)")
            #endif
            return
        }

        record[Field.clientLastModified] = now as CKRecordValue

        let theme = UserDefaults.standard.string(forKey: "stillTheme") ?? StillTheme.light.rawValue
        record[Field.stillTheme] = theme as CKRecordValue

        record[Field.hasCompletedOnboarding] = (UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ? 1 : 0) as CKRecordValue

        if let data = UserDefaults.standard.data(forKey: AlarmConstants.alarmsStorageKey), !data.isEmpty {
            record[Field.alarmsData] = data as CKRecordValue
        } else {
            record[Field.alarmsData] = nil
        }

        if let gData = AppGroupStore.shared.groupsData {
            record[Field.groupsData] = gData as CKRecordValue
        } else {
            record[Field.groupsData] = nil
        }

        record[Field.totalFocusSeconds] = AppGroupStore.shared.totalFocusSeconds as CKRecordValue
        record[Field.completedSessions] = Int64(AppGroupStore.shared.completedSessions) as CKRecordValue

        if let sm = AppGroupStore.shared.stillModeSelectionData {
            record[Field.stillModeSelectionData] = sm as CKRecordValue
        } else {
            record[Field.stillModeSelectionData] = nil
        }

        record[Field.stillProUnlocked] = (UserDefaults.standard.bool(forKey: "stillProUnlocked") ? 1 : 0) as CKRecordValue
        record[Field.alarmQRToken] = AlarmQRTokenStore.token() as CKRecordValue

        let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupId)
        if let logData = groupDefaults?.data(forKey: "stillDailyFocusLog") {
            record[Field.dailyFocusLog] = logData as CKRecordValue
        }
        if let achieveArr = groupDefaults?.stringArray(forKey: "stillUnlockedAchievements") {
            if let achieveData = try? JSONEncoder().encode(achieveArr) {
                record[Field.unlockedAchievements] = achieveData as CKRecordValue
            }
        }

        do {
            try await database.save(record)
            UserDefaults.standard.set(now, forKey: LocalKey.lastAppliedClientMod)
            #if DEBUG
            let alarmBytes = UserDefaults.standard.data(forKey: AlarmConstants.alarmsStorageKey)?.count ?? 0
            log.info("push saved to iCloud (clientLastModified=\(now, privacy: .public), alarmsData bytes=\(alarmBytes, privacy: .public))")
            #endif
        } catch {
            #if DEBUG
            log.error("push save failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    // MARK: - Private

    private static func isCloudAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    @MainActor
    private static func mergeRecordIntoLocalStores(_ record: CKRecord, cloudMod: Double) {
        if let theme = record[Field.stillTheme] as? String, !theme.isEmpty {
            UserDefaults.standard.set(theme, forKey: "stillTheme")
        }

        if let ob = record[Field.hasCompletedOnboarding] as? Int64 {
            UserDefaults.standard.set(ob != 0, forKey: "hasCompletedOnboarding")
        }

        if let data = record[Field.alarmsData] as? Data, !data.isEmpty {
            UserDefaults.standard.set(data, forKey: AlarmConstants.alarmsStorageKey)
            if let alarms = try? JSONDecoder().decode([StoredAlarm].self, from: data) {
                AlarmBootstrap.mirrorAlarmsToSharedDefaults(alarms)
            }
        }

        if let gData = record[Field.groupsData] as? Data {
            AppGroupStore.shared.groupsData = gData
        }

        if let total = record[Field.totalFocusSeconds] as? Double {
            AppGroupStore.shared.totalFocusSeconds = total
        }

        if let count = record[Field.completedSessions] as? Int64 {
            AppGroupStore.shared.completedSessions = Int(count)
        }

        if let sm = record[Field.stillModeSelectionData] as? Data {
            AppGroupStore.shared.stillModeSelectionData = sm
        }

        if let pro = record[Field.stillProUnlocked] as? Int64 {
            UserDefaults.standard.set(pro != 0, forKey: "stillProUnlocked")
        }

        if let token = record[Field.alarmQRToken] as? String, !token.isEmpty {
            AlarmQRTokenStore.replaceTokenForCloudSync(token)
        }

        let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupId)
        if let logData = record[Field.dailyFocusLog] as? Data, !logData.isEmpty {
            groupDefaults?.set(logData, forKey: "stillDailyFocusLog")
        }
        if let achieveData = record[Field.unlockedAchievements] as? Data,
           let arr = try? JSONDecoder().decode([String].self, from: achieveData) {
            groupDefaults?.set(arr, forKey: "stillUnlockedAchievements")
        }

        UserDefaults.standard.set(cloudMod, forKey: LocalKey.lastAppliedClientMod)
        NotificationCenter.default.post(name: .stillCloudPreferencesMerged, object: nil)
    }
}

// MARK: - Debounced push

private final class PushDebouncer: @unchecked Sendable {
    static let shared = PushDebouncer()
    private var task: Task<Void, Never>?
    private let lock = NSLock()

    func schedule(_ operation: @escaping @Sendable () async -> Void) {
        lock.lock()
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await operation()
        }
        lock.unlock()
    }
}
