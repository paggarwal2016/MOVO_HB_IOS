//
//  SealedCryptoService.swift
//  MovocashIOS
//
//  Primitive:  X25519-XSalsa20-Poly1305  (NaCl crypto_box_seal / crypto_box_seal_open)
//  Overhead:   48 bytes per ciphertext   (32-byte ephemeral pk  +  16-byte Poly1305 MAC)
//
//  REQUIRES: Add "Sodium" from the swift-sodium package to the MovocashIOS target.
//  Xcode → Target → General → Frameworks, Libraries, and Embedded Content → + → Sodium
//
//  Key derivation  : CryptoKit Curve25519 (= crypto_scalarmult_base, no Scalarmult class needed)
//  Sealed-box ops  : swift-sodium Box     (= crypto_box_seal / crypto_box_seal_open)
//  Memory wipe     : sodium.utils.zero    (= sodium_memzero, compiler-proof heap wipe)
//

import Foundation
import CryptoKit
import Security
import Sodium

// MARK: - Error

enum SealedCryptoError: Error, LocalizedError, Equatable {
    case keyLoadFailed
    case keyDerivationFailed
    case malformedInput
    case malformedCiphertext
    case decryptionFailed
    case publicKeyImportFailed
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyLoadFailed:        return "Cryptographic key could not be loaded."
        case .keyDerivationFailed:  return "Public-key derivation (Curve25519 scalarmult) failed."
        case .malformedInput:       return "Input is not valid standard base64."
        case .malformedCiphertext:  return "Ciphertext too short — possible truncation or tampering."
        case .decryptionFailed:     return "Decryption failed: key mismatch or MAC verification error."
        case .publicKeyImportFailed:return "RSA public key could not be imported."
        case .encryptionFailed:     return "RSA-OAEP encryption failed."
        }
    }
}

// MARK: - Service

/// Stateless sealed-box crypto namespace.
///
/// Usage:
/// ```swift
/// let data = try SealedBoxCryptoService.decrypt(encryptedBase64: response.encryptedData)
/// let card = try JSONDecoder().decode(VCardsList.self, from: data)
/// ```
enum SealedCryptoService {

    private static let sodium = Sodium()

    // Curve25519 key sizes (fixed by the RFC — not magic numbers)
    private static let secretKeyLength = 32   // crypto_box_secretkeybytes()
    private static let sealOverhead    = 48   // crypto_box_sealbytes() = 32 pk + 16 MAC

    // MARK: - Private Key

    // TODO: Replace with Keychain lookup before production.
    private static func loadSecretKey() throws -> [UInt8] {
        let base64 = "iWXqDFMh19wGaaloJs8SG7/aWNmJJx9JjkJ9Pgju8no="
        guard let data = Data(base64Encoded: base64),
              data.count == secretKeyLength else {
            throw SealedCryptoError.keyLoadFailed
        }
        return [UInt8](data)
    }

    // MARK: - Key Derivation

    /// Derives the Curve25519 public key from a secret key.
    /// CryptoKit performs the identical scalar-base-point multiply as `crypto_scalarmult_base`.
    private static func derivePublicKey(from secretKey: [UInt8]) throws -> [UInt8] {
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(secretKey))
            return [UInt8](privateKey.publicKey.rawRepresentation)
        } catch {
            throw SealedCryptoError.keyDerivationFailed
        }
    }

    // MARK: - Decrypt

    /// Opens a libsodium anonymous sealed box.
    ///
    /// Flow:
    ///   1. Standard-base64 decode the ciphertext.
    ///   2. Load secret key → derive public key (Curve25519 scalarmult base).
    ///   3. `crypto_box_seal_open` — Poly1305 MAC check → XSalsa20 decrypt.
    ///   4. Wipe secret key from heap via sodium_memzero before returning.
    ///
    /// - Parameter encryptedBase64: The `encryptedData` field from the API response.
    /// - Returns: Decrypted plaintext `Data` (pass to `JSONDecoder`).
    static func decrypt(encryptedBase64: String) throws -> Data {
        guard let sealedData = Data(base64Encoded: encryptedBase64) else {
            throw SealedCryptoError.malformedInput
        }
        guard sealedData.count > sealOverhead else {
            throw SealedCryptoError.malformedCiphertext
        }

        var sk = try loadSecretKey()
        defer { sodium.utils.zero(&sk) }

        let pk = try derivePublicKey(from: sk)

        guard let plaintext = sodium.box.open(
            anonymousCipherText: [UInt8](sealedData),
            recipientPublicKey:  pk,
            recipientSecretKey:  sk
        ) else {
            throw SealedCryptoError.decryptionFailed
        }

        return Data(plaintext)
    }

    // MARK: - RSA-OAEP (movo-info)

    /// RSA-OAEP (SHA-256) encrypts `plaintext` with the server's public key and returns
    /// the ciphertext as a **standard base64 string** — the raw blob the server expects
    /// as the `movo-info` header value (no JWT, no dots).
    ///
    /// - Parameters:
    ///   - plaintext: Data to encrypt (the device-info JSON). Must fit a single RSA
    ///     block: for a 2048-bit key the OAEP-SHA256 limit is 190 bytes; 4096-bit is 446.
    ///   - publicKeyBase64: Base64 DER of the server RSA public key
    ///     (`movoSessionConfig` from `/get/config`; PKCS#1 or X.509 SPKI).
    static func rsaOAEPEncrypt(_ plaintext: Data, publicKeyBase64: String) throws -> String {
        // Accept PEM ("-----BEGIN…"), DER base64, with or without line breaks.
        let cleaned = publicKeyBase64
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let der = Data(base64Encoded: cleaned) else {
            throw SealedCryptoError.malformedInput
        }

        let publicKey = try importRSAPublicKey(der: der)

        var error: Unmanaged<CFError>?
        guard let cipher = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionOAEPSHA256,
            plaintext as CFData,
            &error
        ) else {
            throw SealedCryptoError.encryptionFailed
        }

        return (cipher as Data).base64EncodedString()
    }

    /// Imports an RSA public key for encryption. `SecKeyCreateWithData` expects the
    /// PKCS#1 `RSAPublicKey` DER; if the server sends an X.509 SubjectPublicKeyInfo
    /// (the common `MIIBIj…` form), the algorithm-identifier header is stripped first.
    private static func importRSAPublicKey(der: Data) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String:  kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]

        // Try the DER as-is (PKCS#1), then fall back to a stripped X.509 SPKI key.
        for candidate in [der, pkcs1(fromSPKI: der)].compactMap({ $0 }) {
            var error: Unmanaged<CFError>?
            if let key = SecKeyCreateWithData(candidate as CFData, attributes as CFDictionary, &error) {
                return key
            }
        }
        throw SealedCryptoError.publicKeyImportFailed
    }

    /// If `der` is an X.509 SPKI RSA key, returns the inner PKCS#1 `RSAPublicKey` bytes.
    /// Returns nil when no rsaEncryption OID / BIT STRING is found (not an SPKI key).
    private static func pkcs1(fromSPKI der: Data) -> Data? {
        let bytes = [UInt8](der)
        // rsaEncryption OID: 1.2.840.113549.1.1.1
        let rsaOID: [UInt8] = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]

        guard let oidIndex = firstIndex(of: rsaOID, in: bytes) else { return nil }

        // Advance to the BIT STRING (tag 0x03) that follows the AlgorithmIdentifier.
        var i = oidIndex + rsaOID.count
        while i < bytes.count && bytes[i] != 0x03 { i += 1 }
        guard i < bytes.count else { return nil }
        i += 1 // skip the 0x03 tag

        // Skip the BIT STRING length bytes (short or long form).
        guard i < bytes.count else { return nil }
        let lengthByte = Int(bytes[i]); i += 1
        if lengthByte & 0x80 != 0 {
            let lengthCount = lengthByte & 0x7f
            guard lengthCount > 0, i + lengthCount <= bytes.count else { return nil }
            i += lengthCount
        }

        // The BIT STRING's first content byte is the unused-bit count (0x00) — skip it.
        guard i < bytes.count, bytes[i] == 0x00 else { return nil }
        i += 1
        guard i < bytes.count else { return nil }

        return Data(bytes[i...])
    }

    /// First index of `pattern` within `bytes` (plain subsequence search).
    private static func firstIndex(of pattern: [UInt8], in bytes: [UInt8]) -> Int? {
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return nil }
        for start in 0...(bytes.count - pattern.count) {
            var matched = true
            for offset in 0..<pattern.count where bytes[start + offset] != pattern[offset] {
                matched = false
                break
            }
            if matched { return start }
        }
        return nil
    }
}
