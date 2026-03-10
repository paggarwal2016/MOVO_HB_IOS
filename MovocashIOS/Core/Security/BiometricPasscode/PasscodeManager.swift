//
//  PasscodeManaging.swift
//  MovocashIOS
//
//  Created by Vinu on 10/03/26.
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

// MARK: - Errors

enum PasscodeError: LocalizedError {
    case keychainWrite(OSStatus)
    case keychainRead(OSStatus)
    case keychainDelete(OSStatus)
    case secureEnclaveUnavailable
    case keyGenerationFailed(CFError?)
    case hashingFailed
    case notSet

    var errorDescription: String? {
        switch self {
        case .keychainWrite(let s):  return "Keychain write failed (\(s))"
        case .keychainRead(let s):   return "Keychain read failed (\(s))"
        case .keychainDelete(let s): return "Keychain delete failed (\(s))"
        case .secureEnclaveUnavailable: return "Secure Enclave not available on this device"
        case .keyGenerationFailed:   return "Secure Enclave key generation failed"
        case .hashingFailed:         return "PIN hashing failed"
        case .notSet:                return "No passcode has been set"
        }
    }
}

// MARK: - Protocol (enables mocking in tests)

protocol PasscodeManaging {
    var isPasscodeSet: Bool { get }
    var isBiometricKeyEnrolled: Bool { get }
    func setPasscode(_ pin: String) throws
    func verifyPasscode(_ pin: String) throws -> Bool
    func clearPasscode() throws
    func enrollBiometricKey() throws
    func clearBiometricKey() throws
    func clearAll() throws
}

// MARK: - Implementation

final class PasscodeManager: PasscodeManaging, Sendable {

    // MARK: Keychain keys
    private enum Keys {
        static let pinHash = "com.movocash.movo.pin.hash"
        static let pinSalt = "com.movocash.movo.pin.salt"
        static let bioKey  = "com.movocash.movo.bio.key"
    }

    // MARK: - Public state

    var isPasscodeSet: Bool {
        (try? keychainRead(key: Keys.pinHash)) != nil
    }

    var isBiometricKeyEnrolled: Bool {
        secureEnclaveKeyExists()
    }

    // MARK: - Set passcode

    func setPasscode(_ pin: String) throws {
        guard !pin.isEmpty else { throw PasscodeError.hashingFailed }

        // Generate a 32-byte random salt
        var saltBytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard result == errSecSuccess else { throw PasscodeError.hashingFailed }
        let salt = Data(saltBytes)

        let hash = try computeHash(pin: pin, salt: salt)

        try keychainWrite(key: Keys.pinSalt, data: salt)
        try keychainWrite(key: Keys.pinHash, data: hash)
    }

    // MARK: - Verify passcode

    /// Returns true if pin matches stored hash. Throws PasscodeError.notSet if no passcode stored.
    func verifyPasscode(_ pin: String) throws -> Bool {
        guard let storedHash = try? keychainRead(key: Keys.pinHash),
              let salt        = try? keychainRead(key: Keys.pinSalt)
        else {
            throw PasscodeError.notSet
        }
        let candidate = try computeHash(pin: pin, salt: salt)
        // Constant-time comparison to prevent timing attacks
        return constantTimeEqual(lhs: candidate, rhs: storedHash)
    }

    // MARK: - Clear passcode

    func clearPasscode() throws {
        try keychainDelete(key: Keys.pinHash)
        try keychainDelete(key: Keys.pinSalt)
    }

    // MARK: - Biometric Secure Enclave key

    /// Creates a Secure Enclave private key that requires biometric auth on every use.
    /// We only need the key to exist — its presence is the "biometric enrolled" signal.
    func enrollBiometricKey() throws {
        guard SecureEnclave.isAvailable else {
            throw PasscodeError.secureEnclaveUnavailable
        }
        // Remove any stale key first
        try? clearBiometricKey()

        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        )
        guard let access, error == nil else {
            throw PasscodeError.keyGenerationFailed(error?.takeRetainedValue())
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String:            kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String:      256,
            kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String:    true,
                kSecAttrApplicationTag as String: Keys.bioKey.data(using: .utf8)!,
                kSecAttrAccessControl as String:  access
            ]
        ]

        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            throw PasscodeError.keyGenerationFailed(error?.takeRetainedValue())
        }
    }

    func clearBiometricKey() throws {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassKey,
            kSecAttrApplicationTag as String: Keys.bioKey.data(using: .utf8)!,
            kSecAttrKeyType as String:        kSecAttrKeyTypeECSECPrimeRandom
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasscodeError.keychainDelete(status)
        }
    }

    func clearAll() throws {
        try? clearPasscode()
        try? clearBiometricKey()
    }

    // MARK: - Private helpers

    private func computeHash(pin: String, salt: Data) throws -> Data {
        guard let pinData = pin.data(using: .utf8) else { throw PasscodeError.hashingFailed }
        var combined = salt
        combined.append(pinData)
        // SHA-256 via CryptoKit — runs in Secure Enclave-adjacent memory
        let digest = SHA256.hash(data: combined)
        return Data(digest)
    }

    /// Constant-time byte comparison (prevents timing side-channel)
    private func constantTimeEqual(lhs: Data, rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        zip(lhs, rhs).forEach { diff |= $0 ^ $1 }
        return diff == 0
    }

    private func secureEnclaveKeyExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassKey,
            kSecAttrApplicationTag as String: Keys.bioKey.data(using: .utf8)!,
            kSecAttrKeyType as String:        kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String:          false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Keychain CRUD

    private func keychainWrite(key: String, data: Data) throws {
        // Upsert: delete first, then add
        let deleteQuery: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:                   kSecClassGenericPassword,
            kSecAttrAccount as String:             key,
            kSecValueData as String:               data,
            kSecAttrAccessible as String:          kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw PasscodeError.keychainWrite(status) }
    }

    private func keychainRead(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw PasscodeError.keychainRead(status)
        }
        return data
    }

    @discardableResult
    private func keychainDelete(key: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasscodeError.keychainDelete(status)
        }
        return true
    }
}
