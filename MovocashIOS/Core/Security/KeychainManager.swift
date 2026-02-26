//
//  KeychainManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Security
import LocalAuthentication

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

// MARK: - Manager

final class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    private let service = AppInfo.bundleIdentifier + ".secure.keychain"
    
    // MARK: SAVE
    
    func save(
        _ value: String,
        for key: String,
        protection: KeychainProtection
    ) throws {
        
        guard let data = value.data(using: .utf8) else {
            SecureLogger.log("❌ Invalid data for key '\(key)'", level: .error)
            throw KeychainError.invalidData
        }
        
        var query: [String: Any] = baseQuery(for: key)
        
        switch protection {
            
            // Background readable (refresh token)
        case .backgroundSafe:
            query[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecureLogger.log("Saving '\(key)' as BACKGROUND SAFE")
            
            // Requires FaceID / TouchID
        case .userPresence:
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet],
                &error
            ) else {
                SecureLogger.log("❌ Failed creating biometric access control for '\(key)'", level: .error)
                throw error!.takeRetainedValue() as Error
            }
            query[kSecAttrAccessControl as String] = access
            SecureLogger.log("Saving '\(key)' as BIOMETRIC PROTECTED")
        }
        
        // Update or Insert
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            let attributes: [String: Any] = [kSecValueData as String: data]
            try checkStatus(SecItemUpdate(query as CFDictionary, attributes as CFDictionary))
            SecureLogger.log("Updated key '\(key)' successfully")
        } else if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            try checkStatus(SecItemAdd(query as CFDictionary, nil))
            SecureLogger.log("Saved key '\(key)' successfully")
        } else {
            SecureLogger.log("❌ Save failed for '\(key)' OSStatus: \(status)", level: .error)
            try checkStatus(status)
        }
    }
    
    // MARK: GET
    
    func get(
        _ key: String,
        biometricPrompt: String? = nil
    ) throws -> String {
        
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        if let prompt = biometricPrompt {
            let context = LAContext()
            context.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = context
            SecureLogger.log("Reading '\(key)' with biometric prompt")
        } else {
            SecureLogger.log("Reading '\(key)' without biometric")
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            SecureLogger.log("Read key '\(key)' success")
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
            
        case errSecItemNotFound:
            SecureLogger.log("Key '\(key)' not found")
            throw KeychainError.itemNotFound
            
        case errSecAuthFailed:
            SecureLogger.log("Biometric auth failed for '\(key)'")
            throw KeychainError.authFailed
            
        case errSecInteractionNotAllowed:
            SecureLogger.log("'\(key)' blocked — biometric required in background")
            throw KeychainError.interactionNotAllowed
            
        default:
            SecureLogger.log("❌ Read failed '\(key)' OSStatus: \(status)", level: .error)
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: DELETE
    
    func delete(_ key: String) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            SecureLogger.log("Deleted key '\(key)'")
            try checkStatus(status)
        }
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
