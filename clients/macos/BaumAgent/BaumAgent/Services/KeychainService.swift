import Foundation
import Security

struct Credentials {
    let url: String
    let token: String
    let email: String
    let displayName: String
}

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.baumagent.client"

    func hasCredentials() -> Bool {
        return read("token") != nil
    }

    func save(_ creds: Credentials) {
        write("url", value: creds.url)
        write("token", value: creds.token)
        write("email", value: creds.email)
        write("display", value: creds.displayName)
    }

    func load() -> Credentials? {
        guard
            let url = read("url"),
            let token = read("token"),
            let email = read("email"),
            let display = read("display")
        else { return nil }
        return Credentials(url: url, token: token, email: email, displayName: display)
    }

    func clear() {
        for key in ["url", "token", "email", "display"] { delete(key) }
    }

    // MARK: - Private helpers

    private func write(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func read(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
