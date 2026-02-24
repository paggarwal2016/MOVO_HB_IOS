//
//  KeychainManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import Security
import LocalAuthentication

enum KeychainError: Error {
    case invalidData
    case itemNotFound
    case duplicateItem
    case authFailed
    case interactionNotAllowed
    case unexpectedStatus(OSStatus)
}

final class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    private let service = AppInfo.bundleIdentifier + ".keychain"
    
    // MARK: - Save
    
    func save(
        _ value: String,
        for key: String,
        biometricProtected: Bool
    ) throws {
        
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if biometricProtected {
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet, .devicePasscode],
                &error
            ) else {
                if let error = error {
                    throw error.takeRetainedValue() as Error
                } else {
                    throw KeychainError.unexpectedStatus(errSecParam)
                }
            }
            
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Item exists, update it
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            try checkStatus(updateStatus)
        } else if status == errSecItemNotFound {
            // Item doesn't exist, add it
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            try checkStatus(addStatus)
        } else {
            try checkStatus(status)
        }
    }
    
    // MARK: - Get
    
    func get(
        _ key: String,
        biometricPrompt: String? = nil
    ) throws -> String {
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let prompt = biometricPrompt {
            let context = LAContext()
            context.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = context
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedStatus(status)
            }
            return string
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        case errSecAuthFailed:
            throw KeychainError.authFailed
        case errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Delete
    
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecItemNotFound is not an error when deleting
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        case errSecAuthFailed:
            throw KeychainError.authFailed
        case errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Helpers
    
    private func checkStatus(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        case errSecAuthFailed:
            throw KeychainError.authFailed
        case errSecInteractionNotAllowed:
            throw KeychainError.interactionNotAllowed
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
