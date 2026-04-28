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

    /// Synchronous — safe to call at launch before any async context.
    /// Clears auth tokens only; device_id is intentionally preserved.
    func clearAuthTokens() {
        ["access_token", "auth_session_id"].forEach { key in
            SecItemDelete(baseQuery(for: key) as CFDictionary)
        }
        SecureLogger.info("Auth tokens cleared on fresh install", category: .auth)
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
