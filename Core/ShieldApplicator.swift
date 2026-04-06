import FamilyControls
import Foundation
import ManagedSettings

/// Applies or clears shields from the current process (main app or extension).
enum ShieldApplicator {
    private static let store = ManagedSettingsStore()

    static func applyShields(for selection: FamilyActivitySelection) {
        // Reset store so prior session policies (or partial updates) cannot leave apps unblocked.
        store.clearAllSettings()
        store.shield.applications = selection.applicationTokens
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.none
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }
        store.shield.webDomains = selection.webDomainTokens
    }

    static func clearShields() {
        store.clearAllSettings()
    }
}
