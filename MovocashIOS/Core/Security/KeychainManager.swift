//
//  KeychainManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Security
import LocalAuthentication

// MARK: - KeychainManager Protocol

protocol KeychainManagerProtocol: Sendable {
    func save(_ value: String, for key: String, protection: KeychainProtection) async throws

    func get(_ key: String, biometricPrompt: String?) async throws -> String

    func delete(_ key: String) async throws

    /// Synchronous read for app-launch routing. Does NOT prompt biometrics.
    func getSync(_ key: String) -> KeychainSyncResult

    /// Synchronous wipe of auth tokens. Safe to call at launch.
    func clearAuthTokens()
    
    func clearKeychain()
}


// MARK: - KeychainManager

final class KeychainManager: KeychainManagerProtocol {
    
    static let shared = KeychainManager()
    private init() {}
    
    private let service = AppInfo.bundleIdentifier + ".secure.keychain"
    
    // MARK: SAVE
    
    func save(
        _ value: String,
        for key: String,
        protection: KeychainProtection
    ) async throws {
        
        guard let data = value.data(using: .utf8) else {
            SecureLogger.error("Invalid data for key '\(key)'", category: .auth)
            throw KeychainError.invalidData
        }
        
        var query: [String: Any] = baseQuery(for: key)
        
        switch protection {
            
            // Background readable (refresh token)
        case .backgroundSafe:
            query[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecureLogger.info("Saving '\(key)' as BACKGROUND SAFE")
            
            // Requires FaceID / TouchID
        case .userPresence:
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet],
                &error
            ) else {
                SecureLogger.error("Failed creating biometric access control for '\(key)'", category: .auth)
                if let cfError = error?.takeRetainedValue() {
                    throw cfError as Error
                }
                throw KeychainError.unexpectedStatus(errSecParam)
            }
            query[kSecAttrAccessControl as String] = access
            SecureLogger.info("Saving '\(key)' as BIOMETRIC PROTECTED")
        }
        
        // Update or Insert
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            let attributes: [String: Any] = [kSecValueData as String: data]
            try checkStatus(SecItemUpdate(query as CFDictionary, attributes as CFDictionary))
            SecureLogger.info("Updated key '\(key)' successfully")
        } else if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            try checkStatus(SecItemAdd(query as CFDictionary, nil))
            SecureLogger.info("Saved key '\(key)' successfully")
        } else {
            SecureLogger.error("Save failed for '\(key)' OSStatus: \(status)", category: .auth)
            try checkStatus(status)
        }
    }
    
    // MARK: GET
    
    func get(
        _ key: String,
        biometricPrompt: String? = nil
    ) async throws -> String {
        
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        if let prompt = biometricPrompt {
            let context = LAContext()
            context.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = context
            SecureLogger.info("Reading '\(key)' with biometric prompt")
        } else {
            SecureLogger.info("Reading '\(key)' without biometric")
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            SecureLogger.info("Read key '\(key)' success")
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
            
        case errSecItemNotFound:
            SecureLogger.info("Key '\(key)' not found")
            throw KeychainError.itemNotFound
            
        case errSecAuthFailed:
            SecureLogger.info("Biometric auth failed for '\(key)'")
            throw KeychainError.authFailed
            
        case errSecInteractionNotAllowed:
            SecureLogger.info("'\(key)' blocked — biometric required in background")
            throw KeychainError.interactionNotAllowed
            
        default:
            SecureLogger.error("Read failed '\(key)' OSStatus: \(status)", category: .auth)
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: SYNC GET

    func getSync(_ key: String) -> KeychainSyncResult {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                return .missing
            }
            return .found(string)
        case errSecItemNotFound:
            return .missing
        case errSecInteractionNotAllowed:
            return .locked
        default:
            SecureLogger.error("getSync('\(key)') failed OSStatus: \(status)", category: .auth)
            return .missing
        }
    }

    // MARK: DELETE
    
    func delete(_ key: String) async throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            SecureLogger.error("Delete failed for '\(key)' OSStatus: \(status)", category: .auth)
            try checkStatus(status)
            return
        }
        SecureLogger.info("Deleted key '\(key)' successfully")
    }
    
    // MARK: Fresh Install

    func clearAuthTokens() {
        ["access_token", "auth_session_id", "device_session_pubkey", "device_session_id"].forEach { key in
            SecItemDelete(baseQuery(for: key) as CFDictionary)
        }
        SecureLogger.info("Cleared session credentials + device-session config", category: .auth)
    }

    /// Wipes every generic-password entry under this service except `device_id`,
    /// then re-saves the device identity token if one existed.
    ///
    /// Call on fresh install — Keychain survives app uninstalls on iOS, so stale
    /// entries from a previous install (auth tokens, per-user biometric enrollment
    /// flags `biometric_enrolled_<userId>`, passcode hash) persist and cause the
    /// login flow to misroute returning users as still-enrolled. Removing all
    /// service-scoped entries guarantees a clean slate identical to a true first run.
    func clearAllExceptDeviceId() {
        // Capture device_id before the wipe so it can be restored afterwards.
        var savedDeviceId: String?
        if case .found(let id) = getSync("device_id"), !id.isEmpty {
            savedDeviceId = id
        }

        // Delete every generic-password item stored under this app's service.
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Restore device_id so the device fingerprint is preserved across reinstalls.
        if let id = savedDeviceId, let data = id.data(using: .utf8) {
            let saveQuery: [String: Any] = [
                kSecClass as String:          kSecClassGenericPassword,
                kSecAttrService as String:    service,
                kSecAttrAccount as String:    "device_id",
                kSecValueData as String:      data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            SecItemAdd(saveQuery as CFDictionary, nil)
        }

        SecureLogger.info(
            "Fresh install: all Keychain entries wiped (device_id preserved)",
            category: .auth
        )
    }

    // MARK: Helpers

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
    
    private func checkStatus(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess: return
        case errSecDuplicateItem: throw KeychainError.duplicateItem
        case errSecAuthFailed: throw KeychainError.authFailed
        case errSecInteractionNotAllowed: throw KeychainError.interactionNotAllowed
        default: throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func clearKeychain() {
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]

        for secClass in secItemClasses {
            let query: [String: Any] = [
                kSecClass as String: secClass
            ]

            SecItemDelete(query as CFDictionary)
        }

        print("All keychain items deleted")
    }
}





// MARK: - Sync Result

enum KeychainSyncResult {
    case found(String)
    case missing
    case locked   // device not unlocked since reboot
}

// MARK: - Errors

enum KeychainError: Error {
    case invalidData
    case itemNotFound
    case duplicateItem
    case authFailed
    case interactionNotAllowed
    case unexpectedStatus(OSStatus)
}

// MARK: - Protection Levels (IMPORTANT)

enum KeychainProtection {
    /// Used for refresh tokens (background access allowed)
    case backgroundSafe
    
    /// Used for biometric unlock / payments
    case userPresence
}
