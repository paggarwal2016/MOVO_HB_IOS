//
//  RSAKeyManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 11/03/26.
//

import Foundation
import Security

// MARK: - Errors

enum RSAError: LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case signingFailed
    case invalidKeyFormat

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "RSA key generation failed"
        case .keyNotFound: return "Private key not found"
        case .signingFailed: return "Signing failed"
        case .invalidKeyFormat: return "Invalid key format"
        }
    }
}

// MARK: - RSA Manager

final class RSAKeyManager {

    private static let tag: Data = {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.movo.cash"
        guard let data = "\(bundleId).rsa.privatekey".data(using: .utf8) else {
            fatalError("Failed to create key tag")
        }
        return data
    }()

    // MARK: - 1. Generate RSA 2048 Key Pair

    static func generateKeyPair() -> Result<String, RSAError> {

        // Delete existing key if any (clean setup)
        deleteKey()

        var error: Unmanaged<CFError>?

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
        ]

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return .failure(.keyGenerationFailed)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return .failure(.keyGenerationFailed)
        }

        var pubError: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(publicKey, &pubError) as Data? else {
            return .failure(.keyGenerationFailed)
        }

        return .success(pubData.base64EncodedString())
    }

    // MARK: - 2. Build Challenge (WITH / WITHOUT NONCE)

    static func buildChallenge(deviceId: String, nonce: String? = nil) -> Data {
        let timestamp = Int(Date().timeIntervalSince1970)

        let message: String
        if let nonce = nonce {
            message = "login:\(deviceId):\(timestamp):\(nonce)"
        } else {
            message = "login:\(deviceId):\(timestamp)"
        }

        return Data(message.utf8)
    }

    // MARK: - 3. Sign Challenge (RSA PKCS1v1.5 + SHA256)

    static func sign(challenge: Data) -> Result<String, RSAError> {

        guard let privateKey = loadPrivateKey() else {
            return .failure(.keyNotFound)
        }

        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            return .failure(.signingFailed)
        }

        var error: Unmanaged<CFError>?

        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            challenge as CFData,
            &error
        ) as Data? else {
            return .failure(.signingFailed)
        }

        return .success(signature.base64EncodedString())
    }

    // MARK: - 4. Load Private Key

    private static func loadPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            return nil
        }

        let key: SecKey = item as! SecKey
        return key
    }

    // MARK: - 5. Delete Key

    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 6. Check Key Exists

    static func isRegistered() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
