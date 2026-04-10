import Foundation
import Security

enum KeychainHelper {
    private static let service = "co.uk.sharequest.footballcards"
    private static let fallbackPrefix = "co.uk.sharequest.footballcards.fallback."

    private static func fallbackKey(for key: String) -> String {
        fallbackPrefix + key
    }

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            UserDefaults.standard.set(value, forKey: fallbackKey(for: key))
            return true
        }

        UserDefaults.standard.set(value, forKey: fallbackKey(for: key))
        return false
    }

    static func read(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return UserDefaults.standard.string(forKey: fallbackKey(for: key))
        }

        return value
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: key))
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
