import Foundation

struct StoredFocusGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var selectionData: Data
}

enum FocusGroupStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> [StoredFocusGroup] {
        guard let data = AppGroupStore.shared.groupsData,
              let list = try? decoder.decode([StoredFocusGroup].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ groups: [StoredFocusGroup]) {
        guard let data = try? encoder.encode(groups) else { return }
        AppGroupStore.shared.groupsData = data
    }
}
