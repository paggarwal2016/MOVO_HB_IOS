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
import Sodium

// MARK: - Error

enum SealedCryptoError: Error, LocalizedError, Equatable {
    case keyLoadFailed
    case keyDerivationFailed
    case malformedInput
    case malformedCiphertext
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyLoadFailed:       return "Cryptographic key could not be loaded."
        case .keyDerivationFailed: return "Public-key derivation (Curve25519 scalarmult) failed."
        case .malformedInput:      return "Input is not valid standard base64."
        case .malformedCiphertext: return "Ciphertext too short — possible truncation or tampering."
        case .decryptionFailed:    return "Decryption failed: key mismatch or MAC verification error."
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

    // MARK: - HMAC

    /// HMAC-SHA256 of `message` keyed by the server-issued `movoSessionConfig`.
    /// Used to sign the `movo-info` JWT. The key string's UTF-8 bytes form the HMAC
    /// key, following the standard JWT HS256 convention.
    static func hmacSHA256(message: Data, key: String) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(
            for: message,
            using: SymmetricKey(data: Data(key.utf8))
        )
        return Data(mac)
    }
}
