//
//  RSAKeyManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 11/03/26.
//

import Foundation
import LocalAuthentication
import Security

// MARK: - Errors

enum BiometricLoginError: LocalizedError {
    case biometryUnavailable(String)
    case accessControlCreationFailed(String)
    case keyGenerationFailed(String)
    case publicKeyEncodingFailed
    case invalidPayload
    case keyNotFound
    case userCanceled
    case unsupportedAlgorithm
    case signatureFailed(String)

    var errorDescription: String? {
        switch self {
        case .biometryUnavailable(let message):        return message
        case .accessControlCreationFailed(let message): return message
        case .keyGenerationFailed(let message):        return message
        case .publicKeyEncodingFailed:                 return "Failed to encode public key."
        case .invalidPayload:                          return "Invalid payload data."
        case .keyNotFound:                             return "RSA private key not found in Keychain."
        case .userCanceled:                            return "Biometric authentication was cancelled."
        case .unsupportedAlgorithm:                    return "RSA signing algorithm not supported on this device."
        case .signatureFailed(let message):            return message
        }
    }
}

// MARK: - RSAKeyManager

final class RSAKeyManager: Sendable {

    static let shared = RSAKeyManager()

    private init() {}

    private var applicationTagData: Data {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.movo.cash"
        return "\(bundleIdentifier).rsa.privatekey".data(using: .utf8) ?? Data()
    }

    func createKeyPair() throws -> String {
        try ensureBiometryIsAvailable()
        deleteKeyPair()

        // On a real device the key is tied to the device passcode so it is wiped
        // when the passcode is removed — the strongest protection available.
        // On the Simulator there is typically no device passcode, so
        // kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly causes key creation to
        // fail silently; use the weaker (but still device-scoped) protection instead.
        #if targetEnvironment(simulator)
        let keyProtection = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        #else
        let keyProtection = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        #endif

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            keyProtection,
            .biometryAny,
            &accessControlError
        ) else {
            let message = accessControlError?.takeRetainedValue().localizedDescription ?? "Unable to create biometric access control."
            throw BiometricLoginError.accessControlCreationFailed(message)
        }

        let creationContext = LAContext()
        // interactionNotAllowed defaults to false, meaning UI prompts are allowed
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecUseAuthenticationContext as String: creationContext,
                kSecAttrApplicationTag as String: applicationTagData,
                kSecAttrAccessControl as String: accessControl
            ]
        ]

        var generationError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &generationError) else {
            let message = generationError?.takeRetainedValue().localizedDescription ?? "Unable to generate biometric RSA key."
            throw BiometricLoginError.keyGenerationFailed(message)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw BiometricLoginError.publicKeyEncodingFailed
        }

        let pemBody = pemFormattedPublicKeyBody(from: addPublicKeyHeader(to: publicKeyData).base64EncodedString())
        return """
        -----BEGIN PUBLIC KEY-----
        \(pemBody)
        -----END PUBLIC KEY-----
        """
    }

    func keysExist() -> Bool {
        let silentContext = LAContext()
        silentContext.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecUseAuthenticationContext as String: silentContext
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    func deleteKeyPair() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]

        SecItemDelete(query as CFDictionary)
    }

    func createSignature(payload: String, promptMessage: String) throws -> String {
        guard let payloadData = payload.data(using: .utf8) else {
            throw BiometricLoginError.invalidPayload
        }

        let signingContext = LAContext()
        signingContext.localizedReason = promptMessage
        // Empty string hides the "Enter iPhone Passcode" fallback button.
        // When Face ID fails the user sees only Cancel, which throws userCanceled
        // and lets the app show its own PIN screen instead of the system dialog.
        signingContext.localizedFallbackTitle = ""
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: signingContext
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let privateKey = item else {
            if status == errSecUserCanceled {
                throw BiometricLoginError.userCanceled
            }
            throw BiometricLoginError.keyNotFound
        }

        let secKey = privateKey as! SecKey
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

        guard SecKeyIsAlgorithmSupported(secKey, .sign, algorithm) else {
            throw BiometricLoginError.unsupportedAlgorithm
        }

        var signatureError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            secKey,
            algorithm,
            payloadData as CFData,
            &signatureError
        ) as Data? else {
            let error = signatureError?.takeRetainedValue()
            let nsError = error.map { $0 as Error as NSError }

            if let code = nsError?.code,
               code == errSecUserCanceled || code == LAError.userCancel.rawValue {
                throw BiometricLoginError.userCanceled
            }

            let message = error?.localizedDescription ?? "Unable to create biometric signature."
            throw BiometricLoginError.signatureFailed(message)
        }

        return signature.base64EncodedString()
    }

    // MARK: - Private Helpers

    private func ensureBiometryIsAvailable() throws {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard canEvaluate else {
            let message = error?.localizedDescription ?? "Biometric authentication is not available."
            throw BiometricLoginError.biometryUnavailable(message)
        }
    }

    private func addPublicKeyHeader(to publicKeyData: Data) -> Data {
        var builder = [UInt8](repeating: 0, count: 15)
        let encodedRSAEncryptionOID: [UInt8] = [
            0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48,
            0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        ]
        let encodedKey = NSMutableData()

        let bitstringLength: Int
        if publicKeyData.count + 1 < 128 {
            bitstringLength = 1
        } else {
            bitstringLength = ((publicKeyData.count + 1) / 256) + 2
        }

        builder[0] = 0x30
        let totalLength = encodedRSAEncryptionOID.count + 2 + bitstringLength + publicKeyData.count
        let sequenceLength = encodeLength(into: &builder, offset: 1, length: totalLength)
        encodedKey.append(builder, length: sequenceLength + 1)
        encodedKey.append(encodedRSAEncryptionOID, length: encodedRSAEncryptionOID.count)

        builder[0] = 0x03
        let bitstringEncodedLength = encodeLength(into: &builder, offset: 1, length: publicKeyData.count + 1)
        builder[bitstringEncodedLength + 1] = 0x00
        encodedKey.append(builder, length: bitstringEncodedLength + 2)
        encodedKey.append(publicKeyData)

        return encodedKey as Data
    }

    private func encodeLength(into buffer: inout [UInt8], offset: Int, length: Int) -> Int {
        if length < 128 {
            buffer[offset] = UInt8(length)
            return 1
        }

        var value = length
        let byteCount = (length / 256) + 1
        buffer[offset] = UInt8(byteCount + 0x80)

        for index in 0..<byteCount {
            buffer[offset + byteCount - index] = UInt8(value & 0xFF)
            value = value >> 8
        }

        return byteCount + 1
    }

    private func pemFormattedPublicKeyBody(from base64String: String) -> String {
        stride(from: 0, to: base64String.count, by: 64).map { startIndex in
            let start = base64String.index(base64String.startIndex, offsetBy: startIndex)
            let end = base64String.index(start, offsetBy: min(64, base64String.distance(from: start, to: base64String.endIndex)))
            return String(base64String[start..<end])
        }.joined(separator: "\n")
    }
}
