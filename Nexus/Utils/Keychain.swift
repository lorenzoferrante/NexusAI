//
//  Keychain.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 17/08/25.
//

import Foundation
import Supabase
import Security

struct Keychain {
    
    static let OPENROUTER_USER_KEY = "OPENROUTER_USER_KEY"
    static let AUTH_STATE_KEY = "NEXUS_AUTH_STATE"
    static let PROFILE_STATE_KEY = "NEXUS_PROFILE_STATE"

    static func save(_ value: String, for key: String) {
            let data = Data(value.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }

    static func saveFlag(_ value: Bool, for key: String) {
        save(value ? "true" : "false", for: key)
    }

    static func load(_ key: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var out: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data,
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }

    static func loadFlag(_ key: String) -> Bool? {
        guard let value = load(key) else { return nil }
        return value == "true"
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

}
