//
//  RSAKeyManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 11/03/26.
//

import CryptoKit
import Foundation
import Security

// MARK: - Errors

enum RSAKeyAuthError: LocalizedError, Equatable {
    case keyGenerationFailed(String)
    case accessControlFailed
    case keyNotFound
    case signingFailed
    case biometricUnavailable
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let msg): return "Key generation failed: \(msg)"
        case .accessControlFailed:          return "Access control creation failed"
        case .keyNotFound:                  return "Key not found. Please re-register."
        case .signingFailed:                return "Signing failed"
        case .biometricUnavailable:         return "Biometrics not available on this device."
        case .keychainSaveFailed(let s):    return "Keychain save failed with status: \(s)"
        case .keychainLoadFailed:           return "Keychain load failed"
        }
    }
    
    var userMessage: String {
        switch self {
        case .keyNotFound:          return "Login not set up. Please re-register."
        case .biometricUnavailable: return "Face ID / Touch ID not available on this device."
        case .signingFailed:        return "Authentication failed. Please try again."
        default:                    return "Something went wrong. Please try again."
        }
    }
}

// MARK: - RSAKeyManager
//
// Uses a standard CryptoKit P256 key (software, NOT Secure Enclave).
// No biometric or Face ID prompt is ever shown.
// The private key is stored in the Keychain protected by
// kSecAttrAccessibleWhenUnlockedThisDeviceOnly — device passcode only.

final class RSAKeyManager: Sendable {
    
    // MARK: - Keychain key
    
    private static nonisolated let storageKey =
    AppInfo.bundleIdentifier + ".rsa.p256.privatekey"
    
    // MARK: - Generate Key Pair
    //
    // Flow:
    //   1. Generate a P256 private key in software (CryptoKit, no Secure Enclave)
    //   2. Serialize to raw data and save to Keychain (device-unlock protection only)
    //   3. Return public key as Base64 x963 → send to server POST /rsa
    
    static nonisolated func generateKeyPair() -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("generateKeyPair started (software key)", category: .auth)
        
        // Standard software P256 key — no Secure Enclave, no biometric prompt
        let privateKey = P256.Signing.PrivateKey()
        
        let keyData = privateKey.rawRepresentation   // 32-byte scalar
        
        switch saveKeyToKeychain(keyData) {
        case .failure(let error):
            SecureLogger.error("Keychain save failed: \(error)", category: .auth)
            return .failure(error)
        case .success:
            break
        }
        
        let publicKeyBase64 = privateKey.publicKey
            .x963Representation
            .base64EncodedString()
        
        SecureLogger.info("generateKeyPair success — public key ready", category: .auth)
        return .success(publicKeyBase64)
    }
    
    // MARK: - Build Challenge
    //
    // Builds: "login:{deviceId}:{unixTimestamp}"
    // Timestamp makes the message time-bound — server rejects if older than ±30s.
    
    static nonisolated func buildChallenge(deviceId: String) -> Data {
        let timestamp = Int(Date().timeIntervalSince1970)
        let message   = "login:\(deviceId):\(timestamp)"
        let data      = Data(message.utf8)
        SecureLogger.info("Challenge built: \(message)", category: .auth)
        return data
    }
    
    // MARK: - Sign Challenge
    //
    // Flow:
    //   1. Load raw key data from Keychain (no biometric prompt)
    //   2. Reconstruct P256.Signing.PrivateKey from raw bytes
    //   3. Sign challenge and return DER Base64 signature
    
    static nonisolated func sign(
        challenge: Data,
        reason: String = "Authenticate to access MovoCash"   // kept for API compatibility
    ) -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("sign started (software key)", category: .auth)
        
        guard let keyData = loadKeyFromKeychain() else {
            SecureLogger.error("Private key not found in Keychain", category: .auth)
            return .failure(.keyNotFound)
        }
        
        do {
            // Reconstruct from raw 32-byte scalar — no biometric prompt
            let privateKey    = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            let signature     = try privateKey.signature(for: challenge)
            let signedMessage = signature.derRepresentation.base64EncodedString()
            
            SecureLogger.info("sign success", category: .auth)
            return .success(signedMessage)
            
        } catch {
            SecureLogger.error("Signing failed (internal): \(error)", category: .auth)
            return .failure(.signingFailed)
        }
    }
    
    // MARK: - Is Registered
    
    static nonisolated func isRegistered() -> Bool {
        let registered = loadKeyFromKeychain() != nil
        SecureLogger.info("isRegistered: \(registered)", category: .auth)
        return registered
    }
    
    // MARK: - Delete Key
    
    static nonisolated func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: storageKey
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess:
            SecureLogger.info("Private key deleted from Keychain", category: .auth)
        case errSecItemNotFound:
            SecureLogger.info("deleteKey — key was already absent", category: .auth)
        default:
            SecureLogger.warning("deleteKey unexpected status: \(status)", category: .auth)
        }
    }
    
    // MARK: - Keychain (private)
    
    @discardableResult
    private static nonisolated func saveKeyToKeychain(_ data: Data) -> Result<Void, RSAKeyAuthError> {
        deleteKey()   // upsert: remove stale entry first
        
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     storageKey,
            kSecValueData as String:       data,
            kSecAttrAccessible as String:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(.keychainSaveFailed(status))
        }
        SecureLogger.info("Private key blob saved to Keychain", category: .auth)
        return .success(())
    }
    
    // No LAContext needed — item is readable whenever the device is unlocked
    private static nonisolated func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: storageKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
}
