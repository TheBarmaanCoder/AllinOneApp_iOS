import Foundation
import Security

/// Single persistent dismiss token per install (Keychain).
enum AlarmQRTokenStore {
    private static let service = "com.allinoneapp.still"
    private static let account = "alarm_dismiss_token"

    static func token() -> String {
        if let existing = read() { return existing }
        let new = UUID().uuidString
        save(new)
        return new
    }

    static func matches(_ value: String) -> Bool {
        value == token()
    }

    /// Replaces the keychain token when merging from iCloud so all devices share the same QR URL.
    static func replaceTokenForCloudSync(_ string: String) {
        save(string)
    }

    private static func save(_ string: String) {
        let data = Data(string.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data, let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    static var dismissURLString: String {
        "\(AlarmConstants.qrURLScheme)://dismiss?token=\(token())"
    }
}
