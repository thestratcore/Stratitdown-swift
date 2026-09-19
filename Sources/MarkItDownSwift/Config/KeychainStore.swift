import Foundation
import Security

/// Stores the Mistral API key as a generic password item, never on disk in plaintext.
enum KeychainStore {
    private static func query(withValue: Bool, account: String = AppConfig.keychainAccount) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConfig.keychainService,
            kSecAttrAccount as String: account,
        ]
        if withValue {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }

    static func read() -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching(query(withValue: true) as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }

        let data = Data(trimmed.utf8)
        var attributes = query(withValue: false)

        if read() != nil {
            let update: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(attributes as CFDictionary, update as CFDictionary) == errSecSuccess
        } else {
            attributes[kSecValueData as String] = data
            return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        }
    }

    @discardableResult
    static func delete() -> Bool {
        let status = SecItemDelete(query(withValue: false) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Removes the OpenAI key left behind by the pre-Mistral version, so a retired
    /// credential doesn't sit orphaned in the Keychain. Safe to call repeatedly.
    static func deleteLegacyOpenAIKey() {
        let query = query(withValue: false, account: AppConfig.legacyKeychainAccount)
        SecItemDelete(query as CFDictionary)
    }
}
