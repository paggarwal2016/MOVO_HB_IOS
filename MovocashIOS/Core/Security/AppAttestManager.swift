//
//  AttestAPI.swift
//  MovocashIOS
//
//  Apple App Attest (DCAppAttestService) client.
//
//  IMPORTANT: App Attest provides NO security on its own. The private key lives in
//  the Secure Enclave and never leaves the device; the app only produces attestation
//  and assertion blobs. The trust guarantee is entirely server-side — the Skinny
//  Processor must verify the attestation against Apple's App Attest Root CA and verify
//  every assertion's signature + monotonically-increasing counter. See the backend
//  contract:
//
//    POST /attest/challenge  → { challenge }               (one-time, short TTL)
//    POST /attest/register   → { keyId, attestation, challenge }
//    per-request headers      → x-attest-key-id / x-attest-assertion / x-attest-challenge
//

import Foundation
import DeviceCheck
import CryptoKit

actor AppAttestManager {

    nonisolated static let shared = AppAttestManager()

    // MARK: - Result Types

    /// Produced once per install and sent to `POST /attest/register`.
    struct Attestation: Sendable {
        let keyId: String            // base64 (as returned by DCAppAttestService)
        let attestationBase64: String // base64 of the CBOR attestation object
        let challengeBase64: String  // echoed back so the server can match its nonce
    }

    /// Produced per protected request and attached as headers.
    struct Assertion: Sendable {
        let keyId: String
        let assertionBase64: String
        let challengeBase64: String
    }

    // MARK: - State

    private var cachedKeyId: String?

    private var pendingKeyId: String?

    private let keyIdKeychainKey = "appattest_key_id"

    private init() {}

    // MARK: - Support Gate
    /// `nonisolated`: `DCAppAttestService.shared.isSupported` is thread-safe and reads
    /// no actor state.
    nonisolated var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    // MARK: - Attestation (Phase 2 — once per install)
    //
    /// - Parameter challengeBase64: the base64 challenge from `POST /attest/challenge`.
    func prepareAttestation(challengeBase64: String) async throws -> Attestation {
        guard isSupported else { throw AppAttestError.unsupported }

        guard let challengeData = Data(base64Encoded: challengeBase64) else {
            throw AppAttestError.invalidChallenge
        }

        let keyId = try await attestationKeyId()

        // Apple requires clientDataHash = SHA256(challenge) for attestation. The server
        // recomputes it to validate the nonce embedded in the attestation certificate.
        let clientDataHash = Data(SHA256.hash(data: challengeData))

        do {
            let attestation = try await DCAppAttestService.shared.attestKey(
                keyId, clientDataHash: clientDataHash
            )
            return Attestation(
                keyId: keyId,
                attestationBase64: attestation.base64EncodedString(),
                challengeBase64: challengeBase64
            )
        } catch {
            if (error as? DCError)?.code == .invalidKey {
                pendingKeyId = nil
            }
            SecureLogger.error("AppAttest: attestKey failed — \(error.localizedDescription)", category: .security)
            throw AppAttestError.attestationFailed
        }
    }

    /// Persists the key id as the registered key AFTER the server confirms registration
    /// (`POST /attest/register` succeeded). Until this is called, `generateAssertion`
    /// reports `.notAttested`, so a failed registration cannot leave the device stuck
    /// signing with a key the server never accepted.
    func confirmRegistration(keyId: String) async {
        do {
            try await KeychainManager.shared.save(keyId, for: keyIdKeychainKey, protection: .backgroundSafe)
            cachedKeyId = keyId
            if pendingKeyId == keyId { pendingKeyId = nil }
        } catch {
            SecureLogger.error("AppAttest: failed to persist registered key — \(error.localizedDescription)", category: .security)
        }
    }

    // MARK: - Assertion (Phase 3 — per protected request)

    /// Signs `requestBody` bound to a fresh server challenge, for `generateAssertion`.
    /// The client data hashed is `SHA256(challenge ‖ requestBody)`; the server MUST
    /// recompute the same concatenation to verify the signature.
    ///
    /// - Parameters:
    ///   - requestBody: the exact HTTP body bytes the request will send (or empty Data).
    ///   - challengeBase64: the base64 challenge from `POST /attest/challenge`.
    func generateAssertion(requestBody: Data, challengeBase64: String) async throws -> Assertion {
        guard isSupported else { throw AppAttestError.unsupported }

        guard let challengeData = Data(base64Encoded: challengeBase64) else {
            throw AppAttestError.invalidChallenge
        }

        guard let keyId = try await storedKeyId() else {
            throw AppAttestError.notAttested
        }

        var clientData = challengeData
        clientData.append(requestBody)
        let clientDataHash = Data(SHA256.hash(data: clientData))

        do {
            let assertion = try await DCAppAttestService.shared.generateAssertion(
                keyId, clientDataHash: clientDataHash
            )
            return Assertion(
                keyId: keyId,
                assertionBase64: assertion.base64EncodedString(),
                challengeBase64: challengeBase64
            )
        } catch {
            if (error as? DCError)?.code == .invalidKey {
                await reset()
            }
            SecureLogger.error("AppAttest: generateAssertion failed — \(error.localizedDescription)", category: .security)
            throw AppAttestError.assertionFailed
        }
    }

    /// True once a server-confirmed key exists on this install (i.e. registration
    /// has completed). Used by the registration coordinator to stay idempotent and
    /// never re-run attestation for an already-registered device.
    func isRegistered() async -> Bool {
        let keyId = try? await storedKeyId()
        return (keyId ?? nil) != nil
    }

    // MARK: - Key Lifecycle

    func reset() async {
        cachedKeyId = nil
        pendingKeyId = nil
        try? await KeychainManager.shared.delete(keyIdKeychainKey)
    }

    // MARK: - Private
    
    private func storedKeyId() async throws -> String? {
        if let cachedKeyId { return cachedKeyId }
        let value = try? await KeychainManager.shared.get(keyIdKeychainKey, biometricPrompt: nil)
        if let value, !value.isEmpty {
            cachedKeyId = value
            return value
        }
        return nil
    }

    private func attestationKeyId() async throws -> String {
        if let registered = try await storedKeyId() { return registered }
        if let pendingKeyId { return pendingKeyId }

        do {
            let newKeyId = try await DCAppAttestService.shared.generateKey()
            pendingKeyId = newKeyId
            SecureLogger.warning("AppAttest: Secure Enclave key created (keyId \(newKeyId.prefix(8))…)", category: .security)
            return newKeyId
        } catch {
            let code = (error as? DCError)?.code
            SecureLogger.error("AppAttest: generateKey failed — code \(String(describing: code)) — \(error.localizedDescription)", category: .security)
            throw AppAttestError.keyGenerationFailed
        }
    }
}

// MARK: - Errors

enum AppAttestError: Error {
    /// Device/OS does not support App Attest (simulator, no Secure Enclave, etc.).
    case unsupported
    /// The server challenge was not valid base64.
    case invalidChallenge
    /// `DCAppAttestService.generateKey` failed.
    case keyGenerationFailed
    /// `DCAppAttestService.attestKey` failed (includes Apple rate-limiting).
    case attestationFailed
    /// No attested key exists on this install — attestation must run first.
    case notAttested
    /// `DCAppAttestService.generateAssertion` failed.
    case assertionFailed
}
