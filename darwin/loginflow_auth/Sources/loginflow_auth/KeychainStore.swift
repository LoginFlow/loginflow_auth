import Foundation
import Security

enum KeychainStoreError: Error {
    case status(OSStatus)
    case misconfiguredAccessGroup(String)
}

/// Generic-password items with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// and never synchronizable: they do not migrate to another device or iCloud
/// (APPLE-KC-AFU-TDO, OIDC Native SSO §6.2 device binding).
struct KeychainStore {
    let service: String

    /// `nil` stores in the app's default access group; a value shares the
    /// item with every app holding that `keychain-access-groups` entitlement
    /// (APPLE-KC-SHARE).
    let accessGroup: String?

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.status(status)
        }
    }

    func write(account: String, value: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.status(updateStatus)
        }
        let item = baseQuery(account: account).merging(attributes) { _, new in new }
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.status(addStatus)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.status(status)
        }
    }

    /// The access group the system actually assigned to the item.
    func storedAccessGroup(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            let attributes = item as? [String: Any]
            return attributes?[kSecAttrAccessGroup as String] as? String
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.status(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        #if os(macOS)
        // Access groups apply on macOS only with the data protection keychain.
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }
}
