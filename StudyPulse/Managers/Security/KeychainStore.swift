//
//  KeychainStore.swift
//  StudyPulse
//

import Foundation
import Security

/// Minimal generic-password Keychain wrapper used for local secrets.
///
/// Items are explicitly non-synchronizable and use a `ThisDeviceOnly`
/// accessibility class, so they never participate in iCloud Keychain sync.
nonisolated struct KeychainStore: Sendable {
    enum StoreError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    static let shared = KeychainStore(
        service: Bundle.main.bundleIdentifier.map { "\($0).llm-api-keys" }
            ?? "Gao.Chenkai.StudyPulse.llm-api-keys"
    )

    let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw StoreError.invalidData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw StoreError.unexpectedStatus(status)
        }
    }

    func write(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw StoreError.invalidData
        }

        let query = baseQuery(account: account)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            insert[kSecAttrSynchronizable as String] = kCFBooleanFalse
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw StoreError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw StoreError.unexpectedStatus(updateStatus)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}

nonisolated enum LLMAPIKeyAccount {
    static let legacy = "legacy"
    /// StudyPulse Cloud AI 内测 API Key account。
    static let cloud = "cloud"
    /// StudyPulse Cloud AI Session Token（邮箱登录后获取）。
    static let cloudSession = "cloud-session"
    static let authAccessToken = "auth-access-token"
    static let authRefreshToken = "auth-refresh-token"

    static func provider(_ id: UUID) -> String {
        "provider.\(id.uuidString.lowercased())"
    }
}

struct AuthTokenPair: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}

nonisolated struct AuthTokenStore: Sendable {
    static let shared = AuthTokenStore(keychain: .shared)

    let keychain: KeychainStore

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    var accessToken: String? { try? keychain.read(account: LLMAPIKeyAccount.authAccessToken) }
    var refreshToken: String? { try? keychain.read(account: LLMAPIKeyAccount.authRefreshToken) }

    var pair: AuthTokenPair? {
        guard let accessToken, !accessToken.isEmpty,
              let refreshToken, !refreshToken.isEmpty else { return nil }
        return AuthTokenPair(accessToken: accessToken, refreshToken: refreshToken)
    }

    func save(_ pair: AuthTokenPair) throws {
        try keychain.write(pair.accessToken, account: LLMAPIKeyAccount.authAccessToken)
        do {
            try keychain.write(pair.refreshToken, account: LLMAPIKeyAccount.authRefreshToken)
        } catch {
            try? keychain.delete(account: LLMAPIKeyAccount.authAccessToken)
            throw error
        }
    }

    func clear() throws {
        try keychain.delete(account: LLMAPIKeyAccount.authAccessToken)
        try keychain.delete(account: LLMAPIKeyAccount.authRefreshToken)
    }

    func clearIgnoringErrors() {
        try? clear()
    }
}

/// Moves API keys decoded from legacy preference JSON into Keychain.
///
/// A plaintext value is cleared only after the corresponding Keychain item is
/// confirmed to exist or has been written successfully.
nonisolated enum LLMAPIKeyMigrator {
    @discardableResult
    static func migrate(
        preferences: inout AppPreferences,
        keychain: KeychainStore
    ) -> Bool {
        var changed = false

        for index in preferences.llmProviders.indices {
            guard let legacyKey = normalized(preferences.llmProviders[index].legacyAPIKey) else {
                continue
            }
            let account = LLMAPIKeyAccount.provider(preferences.llmProviders[index].id)
            do {
                if try keychain.read(account: account) == nil {
                    try keychain.write(legacyKey, account: account)
                }
                preferences.llmProviders[index].legacyAPIKey = nil
                changed = true
            } catch {
                // Keep the legacy value so a later launch can retry without data loss.
            }
        }

        if preferences.llmAPIKey != nil, normalized(preferences.llmAPIKey) == nil {
            preferences.llmAPIKey = nil
            changed = true
        } else if let legacyKey = normalized(preferences.llmAPIKey) {
            do {
                let activeProviderAccount = preferences.activeLLMProviderId
                    .map(LLMAPIKeyAccount.provider)
                let activeProviderHasKey = try activeProviderAccount
                    .map { try keychain.read(account: $0) != nil } ?? false

                if !activeProviderHasKey,
                   try keychain.read(account: LLMAPIKeyAccount.legacy) == nil {
                    try keychain.write(legacyKey, account: LLMAPIKeyAccount.legacy)
                }
                preferences.llmAPIKey = nil
                changed = true
            } catch {
                // Keep the legacy value so a later launch can retry without data loss.
            }
        }

        return changed
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
