//
//  RSAKeyManager.swift
//  MovocashIOS
//
//  Created by Vinu on 11/03/26.
//

import CryptoKit
import LocalAuthentication
import Foundation

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
        case .keyNotFound:                  return "Biometric key not found. Please re-register."
        case .signingFailed:                return "Signing failed"   // no internal detail
        case .biometricUnavailable:         return "Biometrics not available on this device."
        case .keychainSaveFailed(let s):    return "Keychain save failed with status: \(s)"
        case .keychainLoadFailed:           return "Keychain load failed"
        }
    }

    var userMessage: String {
        switch self {
        case .keyNotFound:          return "Biometric login not set up. Please re-register."
        case .biometricUnavailable: return "Face ID / Touch ID not available on this device."
        case .signingFailed:        return "Authentication failed. Please try again."
        default:                    return "Something went wrong. Please try again."
        }
    }
}

// MARK: - RSAKeyManager

final class RSAKeyManager: Sendable {

    // MARK: - Private

    private static nonisolated let storageKey = AppInfo.bundleIdentifier + ".rsa.p256.privatekey"

    // MARK: - Biometric Availability

    static func isBiometricAvailable() -> Bool {
        guard SecureEnclave.isAvailable else {
            SecureLogger.warning("Secure Enclave not available", category: .auth)
            return false
        }
        let ctx = LAContext()
        var error: NSError?
        let available = ctx.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        if !available {
            SecureLogger.warning("Biometric unavailable: \(error?.localizedDescription ?? "unknown")", category: .auth)
        }
        return available
    }

    // MARK: - Generate Key Pair
    //
    // Flow:
    //   1. Check Secure Enclave available
    //   2. Create access control (biometryCurrentSet)
    //   3. Generate P256 private key inside Secure Enclave
    //   4. Save opaque key blob to Keychain with biometric-grade protection
    //   5. Return public key as Base64 x963 → send to server POST /rsa

    static nonisolated func generateKeyPair() -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("generateKeyPair started", category: .auth)

        guard SecureEnclave.isAvailable else {
            SecureLogger.error("Secure Enclave unavailable", category: .auth)
            return .failure(.biometricUnavailable)
        }

        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            SecureLogger.error("Access control creation failed", category: .auth)
            return .failure(.accessControlFailed)
        }

        do {
            let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
                accessControl: access
            )

            switch saveKeyToKeychain(privateKey.dataRepresentation) {
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

        } catch {
            SecureLogger.error("P256 key generation failed: \(error)", category: .auth)
            return .failure(.keyGenerationFailed(error.localizedDescription))
        }
    }

    // MARK: - Build Challenge
    //
    // Builds: "login:{deviceId}:{unixTimestamp}"
    // UTF-8 encoding of ASCII string never fails — returns Data directly.
    // Timestamp makes the message time-bound — server rejects if older than ±30s.

    static nonisolated func buildChallenge(deviceId: String) -> Data {
        let timestamp = Int(Date().timeIntervalSince1970)
        let message   = "login:\(deviceId):\(timestamp)"
        let data      = Data(message.utf8)   // UTF-8 on ASCII never fails
        SecureLogger.info("Challenge built: \(message)", category: .auth)
        return data
    }

    // MARK: - Sign Challenge
    //
    // Flow:
    //   1. Load opaque key blob from Keychain (requires device unlocked)
    //   2. Attach LAContext with kSecUseAuthenticationUI enforced
    //   3. Reconstruct P256 key — biometric prompt fires here
    //   4. Sign challenge bytes
    //   5. Return DER Base64 signature → signedMessage for POST /auth/token-rsa

    static nonisolated func sign(
        challenge: Data,
        reason: String = "Authenticate to access MovoCash"
    ) -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("sign started", category: .auth)

        // return the blob without biometric evaluation.
        let context = LAContext()
        context.localizedReason        = reason
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle   = "Cancel"

        guard let keyData = loadKeyFromKeychain(context: context) else {
            SecureLogger.error("Private key not found in Keychain", category: .auth)
            return .failure(.keyNotFound)
        }

        do {
            // Biometric prompt fires here via the bound LAContext
            let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
                dataRepresentation: keyData,
                authenticationContext: context
            )

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
        let registered = loadKeyFromKeychain(context: nil) != nil
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
        if status == errSecSuccess {
            SecureLogger.info("Private key deleted from Keychain", category: .auth)
        } else if status == errSecItemNotFound {
            SecureLogger.info("deleteKey — key was already absent", category: .auth)
        } else {
            SecureLogger.warning("deleteKey unexpected status: \(status)", category: .auth)
        }
    }

    // MARK: - Keychain (private)

    @discardableResult
    private static nonisolated func saveKeyToKeychain(_ data: Data) -> Result<Void, RSAKeyAuthError> {
        deleteKey()

        // access control — requires biometric evaluation to read back,
        // not just device-unlocked state.
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,        // ← matches key's own access control
            nil
        ) else {
            return .failure(.accessControlFailed)
        }

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      storageKey,
            kSecValueData as String:        data,
            kSecAttrAccessControl as String: access   // ← replaces kSecAttrAccessible
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(.keychainSaveFailed(status))
        }
        SecureLogger.info("Private key blob saved to Keychain", category: .auth)
        return .success(())
    }

    // evaluate biometric before returning the blob, preventing silent reads.
    private static nonisolated func loadKeyFromKeychain(context: LAContext?) -> Data? {
        // Use provided context or create a default one.
        // interactionNotAllowed = false → OS is allowed to show biometric UI,
        // replacing the deprecated kSecUseAuthenticationUIAllow.
        let ctx = context ?? LAContext()
        ctx.interactionNotAllowed = false   // require biometric UI, never skip silently

        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          storageKey,
            kSecReturnData as String:           true,
            kSecMatchLimit as String:           kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: ctx
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
}
