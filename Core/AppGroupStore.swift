import Foundation

/// App Group–backed persistence shared with extensions.
final class AppGroupStore {
    static let shared = AppGroupStore()

    private let defaults: UserDefaults?
    private let sessionSelectionFileName = "session_focus_selection.plist"

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupId)
    }

    private enum Key {
        static let selectionData = "selectionData"
        static let sessionActive = "sessionActive"
        static let sessionEnd = "sessionEnd"
        static let sessionStart = "sessionStart"
        static let totalFocusSeconds = "totalFocusSeconds"
        static let completedSessions = "completedSessions"
        static let groupsData = "groupsData"
        static let stillModeActive = "stillModeActive"
        static let stillModeStart = "stillModeStart"
        static let stillModeSelectionData = "stillModeSelectionData"
        /// When true, `sessionActive` was started by a scheduled block; suppress focus Live Activity (cheat LA still allowed).
        static let sessionIsScheduled = "sessionIsScheduled"
        /// UUID string of the `ScheduledBlock` for the active scheduled session (for UI).
        static let scheduledBlockSessionId = "scheduledBlockSessionId"
    }

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupId)
    }

    /// Call before reading shared keys after another process (shield / monitor extension) may have written, so this process sees up‑to‑date values.
    func synchronizeForCrossProcessRead() {
        defaults?.synchronize()
    }

    /// Legacy UserDefaults access; prefer `loadSessionSelectionData` / `persistSessionSelection` for the active session blob.
    var selectionData: Data? {
        get { loadSessionSelectionData() }
        set {
            if let newValue {
                persistSessionSelection(newValue)
            } else {
                clearSessionSelectionBlob()
            }
        }
    }

    /// Writes merged `FamilyActivitySelection` for the monitor extension: UserDefaults + atomic file (extension reads file first).
    func persistSessionSelection(_ data: Data) {
        defaults?.set(data, forKey: Key.selectionData)
        guard let dir = sharedContainerURL else { return }
        let url = dir.appendingPathComponent(sessionSelectionFileName)
        try? data.write(to: url, options: .atomic)
    }

    func loadSessionSelectionData() -> Data? {
        if let dir = sharedContainerURL {
            let url = dir.appendingPathComponent(sessionSelectionFileName)
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               !data.isEmpty {
                return data
            }
        }
        return defaults?.data(forKey: Key.selectionData)
    }

    func clearSessionSelectionBlob() {
        defaults?.removeObject(forKey: Key.selectionData)
        if let dir = sharedContainerURL {
            let url = dir.appendingPathComponent(sessionSelectionFileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

    var sessionActive: Bool {
        get { defaults?.bool(forKey: Key.sessionActive) ?? false }
        set { defaults?.set(newValue, forKey: Key.sessionActive) }
    }

    var sessionEnd: Date? {
        get { defaults?.object(forKey: Key.sessionEnd) as? Date }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.sessionEnd)
            } else {
                defaults?.removeObject(forKey: Key.sessionEnd)
            }
        }
    }

    var sessionStart: Date? {
        get { defaults?.object(forKey: Key.sessionStart) as? Date }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.sessionStart)
            } else {
                defaults?.removeObject(forKey: Key.sessionStart)
            }
        }
    }

    var totalFocusSeconds: TimeInterval {
        get { defaults?.double(forKey: Key.totalFocusSeconds) ?? 0 }
        set { defaults?.set(newValue, forKey: Key.totalFocusSeconds) }
    }

    var completedSessions: Int {
        get { defaults?.integer(forKey: Key.completedSessions) ?? 0 }
        set { defaults?.set(newValue, forKey: Key.completedSessions) }
    }

    var groupsData: Data? {
        get { defaults?.data(forKey: Key.groupsData) }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.groupsData)
            } else {
                defaults?.removeObject(forKey: Key.groupsData)
            }
        }
    }

    func clearSessionMetadata() {
        sessionActive = false
        sessionEnd = nil
        sessionStart = nil
        sessionIsScheduled = false
        scheduledBlockSessionId = nil
        clearSessionSelectionBlob()
    }

    var sessionIsScheduled: Bool {
        get { defaults?.bool(forKey: Key.sessionIsScheduled) ?? false }
        set { defaults?.set(newValue, forKey: Key.sessionIsScheduled) }
    }

    var scheduledBlockSessionId: String? {
        get { defaults?.string(forKey: Key.scheduledBlockSessionId) }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.scheduledBlockSessionId)
            } else {
                defaults?.removeObject(forKey: Key.scheduledBlockSessionId)
            }
        }
    }

    // MARK: - Still Mode

    var stillModeActive: Bool {
        get { defaults?.bool(forKey: Key.stillModeActive) ?? false }
        set {
            defaults?.set(newValue, forKey: Key.stillModeActive)
            defaults?.synchronize()
        }
    }

    var stillModeStart: Date? {
        get { defaults?.object(forKey: Key.stillModeStart) as? Date }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.stillModeStart)
            } else {
                defaults?.removeObject(forKey: Key.stillModeStart)
            }
        }
    }

    var stillModeSelectionData: Data? {
        get { defaults?.data(forKey: Key.stillModeSelectionData) }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: Key.stillModeSelectionData)
            } else {
                defaults?.removeObject(forKey: Key.stillModeSelectionData)
            }
        }
    }

    func clearStillModeMetadata() {
        stillModeActive = false
        stillModeStart = nil
    }
}
