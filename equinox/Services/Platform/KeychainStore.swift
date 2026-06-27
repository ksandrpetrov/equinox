import Foundation
import Security

enum KeychainStore {
    private static let service = "equinox.plaud.oauth"

    static func save(data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.saveFailed(status)
        }
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainStoreError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            if status == -67_820 {
                return String(
                    localized: "Could not save Plaud credentials because the app signature is invalid or signed with a revoked certificate. Rebuild Equinox with valid local signing and try again.",
                    comment: "Plaud keychain revoked certificate error"
                )
            }

            if let systemMessage = SecCopyErrorMessageString(status, nil) as String? {
                return String(
                    localized: "Could not save Plaud credentials (Keychain error \(status): \(systemMessage)).",
                    comment: "Plaud keychain save error with system detail"
                )
            }

            return String(
                localized: "Could not save Plaud credentials (Keychain error \(status)).",
                comment: "Plaud keychain save error"
            )
        }
    }
}
