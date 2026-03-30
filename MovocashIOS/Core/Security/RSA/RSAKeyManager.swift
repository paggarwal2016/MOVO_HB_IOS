//
//  RSAKeyManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 11/03/26.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

// MARK: - Errors

enum RSAKeyAuthError: LocalizedError, Equatable {
    case keyGenerationFailed(String)
    case accessControlFailed
    case keyNotFound
    case signingFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let msg): return "Key generation failed: \(msg)"
        case .accessControlFailed:          return "Access control creation failed"
        case .keyNotFound:                  return "Key not found. Please re-register."
        case .signingFailed:                return "Signing failed"
        case .keychainSaveFailed(let s):    return "Keychain save failed with status: \(s)"
        case .keychainLoadFailed:           return "Keychain load failed"
        }
    }

    var userMessage: String {
        switch self {
        case .keyNotFound:          return "Login not set up. Please re-register."
        case .signingFailed:        return "Authentication failed. Please try again."
        default:                    return "Something went wrong. Please try again."
        }
    }
}

// MARK: - RSAKeyManager
//
// Real device (SE available):
//   Private key lives entirely inside the Secure Enclave chip — never exported.
//   Signing triggers Face ID / Touch ID when the device has biometric enrolled.
//   Devices without biometric still benefit from SE hardware protection.
//
// Simulator / SE unavailable:
//   Falls back to a software P256 key stored in the Keychain.

final class RSAKeyManager: Sendable {

    // MARK: - Constants

    private static let serviceKey  = AppInfo.bundleIdentifier
    private static let storageKey  = "rsa.p256.privatekey"

    // SE availability is a hardware property — evaluate once at launch, not per call.
    // SecureEnclave types compile on the simulator; isAvailable just returns false there.
    private static let useSecureEnclave = SecureEnclave.isAvailable

    // MARK: - Public API

    static func generateKeyPair() -> Result<String, RSAKeyAuthError> {
        useSecureEnclave ? generateSEKeyPair() : generateSoftwareKeyPair()
    }

    /// Builds a time-bound challenge string and returns it as UTF-8 data.
    ///
    /// Format without nonce:  `login:{deviceId}:{unixTimestamp}`
    /// Format with nonce:     `login:{deviceId}:{unixTimestamp}:{nonce}`
    ///
    /// The server rejects challenges older than ±30 s.
    /// Providing a server-issued `nonce` eliminates the replay window entirely —
    /// the server must enforce single-use nonce uniqueness for this to be effective.
    static func buildChallenge(deviceId: String, nonce: String? = nil) -> Data {
        var message = "login:\(deviceId):\(Int(Date().timeIntervalSince1970))"
        if let nonce {
            message += ":\(nonce)"
        }
        SecureLogger.info("Challenge built\(nonce != nil ? " (with server nonce)" : "")", category: .auth)
        return Data(message.utf8)
    }

    /// Signs `challenge` with the stored private key.
    /// On a device with SE + biometric, Face ID / Touch ID fires during this call.
    /// Must be called from a background thread — blocks until biometric completes.
    static func sign(
        challenge: Data,
        reason: String = "Authenticate to access MovoCash"
    ) -> Result<String, RSAKeyAuthError> {
        useSecureEnclave
            ? signWithSEKey(challenge: challenge)
            : signWithSoftwareKey(challenge: challenge)
    }

    static func isRegistered() -> Bool {
        let registered = loadKeyFromKeychain() != nil
        SecureLogger.info("isRegistered: \(registered)", category: .auth)
        return registered
    }

    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceKey,
            kSecAttrAccount as String: storageKey
        ]
        switch SecItemDelete(query as CFDictionary) {
        case errSecSuccess:      SecureLogger.info("Private key deleted", category: .auth)
        case errSecItemNotFound: SecureLogger.info("deleteKey — already absent", category: .auth)
        case let s:              SecureLogger.warning("deleteKey unexpected status: \(s)", category: .auth)
        }
    }
}

// MARK: - Secure Enclave path

private extension RSAKeyManager {

    static func generateSEKeyPair() -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("generateKeyPair (Secure Enclave)", category: .auth)

        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            seAccessFlags(),
            &cfError
        ) else {
            SecureLogger.error("Access control creation failed", category: .auth)
            return .failure(.accessControlFailed)
        }

        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)

            if case .failure(let error) = saveKeyToKeychain(key.dataRepresentation) {
                return .failure(error)
            }

            SecureLogger.info("generateKeyPair success (SE)", category: .auth)
            return .success(key.publicKey.x963Representation.base64EncodedString())
        } catch {
            SecureLogger.error("SE key generation failed: \(error.localizedDescription)", category: .auth)
            return .failure(.keyGenerationFailed(error.localizedDescription))
        }
    }

    static func signWithSEKey(challenge: Data) -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("sign (Secure Enclave)", category: .auth)

        guard let keyData = loadKeyFromKeychain() else {
            SecureLogger.error("Private key not found in Keychain", category: .auth)
            return .failure(.keyNotFound)
        }

        // Stage 1 — reconstruct SE key handle from stored opaque blob.
        // No LAContext needed — key has no biometric access control requirement.
        // Fails if the stored data is incompatible (e.g. a stale .biometryCurrentSet key).
        let key: SecureEnclave.P256.Signing.PrivateKey
        do {
            key = try SecureEnclave.P256.Signing.PrivateKey(
                dataRepresentation: keyData
            )
        } catch let cryptoError as CryptoKitError {
            // Stale key format — delete so re-enrollment runs on the next login attempt.
            SecureLogger.warning("SE key init failed (\(cryptoError)) — clearing for re-enroll", category: .auth)
            deleteKey()
            return .failure(.keyNotFound)
        } catch {
            // Transient error (device locked, SE temporarily unavailable) — keep key, let caller retry.
            SecureLogger.error("SE key init transient error: \(error.localizedDescription)", category: .auth)
            return .failure(.signingFailed)
        }

        // Stage 2 — sign. No biometric prompt — SE performs the operation using
        // device-unlock protection only. Do NOT delete the key on failure here;
        // a transient SE error should be retried, not treated as key corruption.
        do {
            let signature = try key.signature(for: challenge)
            SecureLogger.info("sign success (SE)", category: .auth)
            return .success(signature.derRepresentation.base64EncodedString())
        } catch {
            SecureLogger.error("SE sign failed: \(error.localizedDescription)", category: .auth)
            return .failure(.signingFailed)
        }
    }

    /// SE hardware protection only — private key is non-extractable from the chip
    /// but no biometric prompt is required on each sign operation.
    /// App-level biometric is handled separately by AppLockManager before the user
    /// reaches any screen that triggers RSA login.
    static func seAccessFlags() -> SecAccessControlCreateFlags {
        [.privateKeyUsage]
    }
}

// MARK: - Software key path (simulator / SE unavailable)

private extension RSAKeyManager {

    static func generateSoftwareKeyPair() -> Result<String, RSAKeyAuthError> {
        SecureLogger.info("generateKeyPair (software — SE unavailable)", category: .auth)

        let key = P256.Signing.PrivateKey()

        if case .failure(let error) = saveKeyToKeychain(key.rawRepresentation) {
            return .failure(error)
        }

        SecureLogger.info("generateKeyPair success (software)", category: .auth)
        return .success(key.publicKey.x963Representation.base64EncodedString())
    }

    static func signWithSoftwareKey(challenge: Data) -> Result<String, RSAKeyAuthError> {
        guard let keyData = loadKeyFromKeychain() else {
            return .failure(.keyNotFound)
        }
        do {
            let signature = try P256.Signing.PrivateKey(rawRepresentation: keyData)
                .signature(for: challenge)
            return .success(signature.derRepresentation.base64EncodedString())
        } catch {
            return .failure(.signingFailed)
        }
    }
}

// MARK: - Keychain

private extension RSAKeyManager {

    /// Upsert: attempts add first; if a duplicate exists, updates in place.
    /// Avoids the delete-then-add pattern which creates a brief window where
    /// the key is absent and requires two round-trips instead of one.
    @discardableResult
    static func saveKeyToKeychain(_ data: Data) -> Result<Void, RSAKeyAuthError> {
        let addQuery: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    serviceKey,
            kSecAttrAccount as String:    storageKey,
            kSecValueData as String:      data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String: serviceKey,
                kSecAttrAccount as String: storageKey
            ]
            status = SecItemUpdate(
                searchQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }

        guard status == errSecSuccess else {
            SecureLogger.error("Key save failed with Keychain status: \(status)", category: .auth)
            return .failure(.keychainSaveFailed(status))
        }
        SecureLogger.info("Key blob saved to Keychain", category: .auth)
        return .success(())
    }

    static func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceKey,
            kSecAttrAccount as String: storageKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
            ? result as? Data
            : nil
    }
}
