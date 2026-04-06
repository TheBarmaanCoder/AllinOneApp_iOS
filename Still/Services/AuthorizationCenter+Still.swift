import FamilyControls
import Foundation

enum FocusAuthorization {
    static func authorizationStatus() -> AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
    }

    static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
