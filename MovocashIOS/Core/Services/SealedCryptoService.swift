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
        case .publicKeyImportFailed:return "Public key could not be imported."
        case .encryptionFailed:     return "Encryption failed."
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

    // Curve25519 key sizes (fixed by the RFC — not magic numbers).
    // `nonisolated` so the nonisolated crypto methods can read them under the
    // project's main-actor-default isolation.
    nonisolated private static let secretKeyLength = 32   // crypto_box_secretkeybytes()
    nonisolated private static let sealOverhead    = 48   // crypto_box_sealbytes() = 32 pk + 16 MAC

    // MARK: - Private Key

    // TODO: Replace with Keychain lookup before production.
    private static func loadSecretKey() throws -> [UInt8] {
        let base64 = AppConfig.cryptoKey
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

    // MARK: - Encrypt (anonymous sealed box — inverse of `decrypt`)

    /// Seals `plaintext` into a libsodium anonymous sealed box (`crypto_box_seal`)
    /// addressed to the public key derived from the configured secret key
    /// (`AppConfig.cryptoKey`). The result is openable by `decrypt` (or the backend
    /// holding the same key). Output is standard base64.
    ///
    /// NOTE: `crypto_box_seal` uses a fresh random ephemeral key per call, so the same
    /// plaintext yields a different ciphertext every time — each one opens back to the
    /// same plaintext. Do not assert on a fixed ciphertext in tests.
    static func encrypt(_ plaintext: Data) throws -> String {
        var sk = try loadSecretKey()
        defer { sodium.utils.zero(&sk) }

        let pk = try derivePublicKey(from: sk)

        guard let sealed = sodium.box.seal(
            message: [UInt8](plaintext),
            recipientPublicKey: pk
        ) else {
            throw SealedCryptoError.encryptionFailed
        }
        return Data(sealed).base64EncodedString()
    }

    /// Convenience for UTF-8 string plaintext (e.g. a password).
    static func encrypt(_ string: String) throws -> String {
        try encrypt(Data(string.utf8))
    }

    // MARK: - X25519 + HKDF + AES-256-GCM (secure movo-info)

    /// Builds the binary blob for the X25519 variant of the `movo-info` header.
    ///
    /// Scheme (must match the server exactly):
    ///   1. Generate an ephemeral X25519 key pair (throwaway, per request).
    ///   2. ECDH with the server's X25519 public key → 32-byte shared secret.
    ///   3. HKDF-SHA256(secret, salt: empty, info: "movo-device-info") → 32-byte AES key.
    ///   4. AES-256-GCM seal the plaintext with a random 12-byte nonce.
    ///   5. blob = clientPublicKey[32] ‖ nonce[12] ‖ ciphertext ‖ tag[16]
    ///
    /// - Parameters:
    ///   - plaintext: The device-info JSON to encrypt.
    ///   - serverPublicKeyBase64: `movoSessionConfig` from `/device/config` — a
    ///     standard-base64 raw 32-byte X25519 public key (44 base64 chars).
    /// - Returns: Standard-base64 of the assembled blob (the part after the `sessionId.`).
    nonisolated static func sealDeviceInfo(_ plaintext: Data, serverPublicKeyBase64: String) throws -> String {
        let cleaned = serverPublicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let serverKeyData = Data(base64Encoded: cleaned),
              serverKeyData.count == secretKeyLength else {
            throw SealedCryptoError.malformedInput
        }

        let serverPublicKey: Curve25519.KeyAgreement.PublicKey
        do {
            serverPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverKeyData)
        } catch {
            throw SealedCryptoError.publicKeyImportFailed
        }

        // Step 1 — ephemeral client key pair.
        let clientPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let clientPublicKey = clientPrivateKey.publicKey.rawRepresentation // 32 bytes

        // Step 2 — ECDH shared secret.
        let sharedSecret: SharedSecret
        do {
            sharedSecret = try clientPrivateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)
        } catch {
            throw SealedCryptoError.keyDerivationFailed
        }

        // Step 3 — HKDF-SHA256 → AES-256 key. Empty salt; info pins the context.
        let aesKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("movo-device-info".utf8),
            outputByteCount: secretKeyLength
        )

        // Step 4 — AES-256-GCM. `seal` generates a random 12-byte nonce; `combined`
        // is `nonce[12] ‖ ciphertext ‖ tag[16]`.
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(plaintext, using: aesKey)
        } catch {
            throw SealedCryptoError.encryptionFailed
        }
        guard let combined = sealedBox.combined else {
            throw SealedCryptoError.encryptionFailed
        }

        // Step 5 — assemble: clientPublicKey ‖ (nonce ‖ ciphertext ‖ tag).
        var blob = Data()
        blob.append(clientPublicKey)
        blob.append(combined)
        return blob.base64EncodedString()
    }

}
