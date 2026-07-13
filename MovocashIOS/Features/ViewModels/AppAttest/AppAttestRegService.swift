//
//  AppAttestRegService.swift
//  MovocashIOS
//

import Foundation

actor AppAttestRegistrationService {

    static let shared = AppAttestRegistrationService()
    private init() {}

    /// Guards against concurrent runs (e.g. two rapid login completions) so a second
    /// invocation can never trigger a second `attestKey` on an unconfirmed key.
    private var inFlight = false

    /// Max attempts for the `/attest/register` POST only. Attestation itself is never
    /// repeated within a run.
    private let maxRegisterAttempts = 3

    private let manager = AppAttestManager.shared

    /// Best-effort, idempotent registration. Safe to call after every login — it
    /// no-ops when the device is unsupported or already registered.
    func registerIfNeeded() async {
        guard manager.isSupported else { return }
        guard !inFlight else { return }
        guard await !manager.isRegistered() else { return }

        inFlight = true
        defer { inFlight = false }

        do {
            // Step 1 — one-time challenge.
            let challenge: AttestChallengeResponse = try await NetworkService.shared.request(AttestAPI.challenge)

            // Step 2 — produce the attestation. `attestKey` runs EXACTLY ONCE here.
            let attestation = try await manager.prepareAttestation(challengeBase64: challenge.challenge)

            // Step 3 — register, retrying ONLY the POST with the same blob on transient errors.
            try await register(attestation)

        } catch {
            // Any failure before/after registration → discard the (unconfirmed) key so the
            // next login regenerates a fresh key instead of re-attesting this one.
            SecureLogger.warning("AppAttest: registration flow aborted — \(error.localizedDescription)", category: .security)
            await manager.reset()
        }
    }

    // MARK: - Private

    /// POSTs the attestation, retrying the request (not the attestation) on transient
    /// network failures. Throws on give-up so the caller can `reset()`.
    private func register(_ attestation: AppAttestManager.Attestation) async throws {
        let request = AttestRegisterRequest(
            keyId: attestation.keyId,
            attestation: attestation.attestationBase64,
            challenge: attestation.challengeBase64
        )

        var lastError: Error = AppAttestError.attestationFailed

        for attempt in 1...maxRegisterAttempts {
            do {
                let response: AttestRegisterResponse = try await NetworkService.shared.request(
                    AttestAPI.register(request: request)
                )
                guard response.success != false else {
                    throw AppAttestError.attestationFailed
                }
                await manager.confirmRegistration(keyId: attestation.keyId)
                SecureLogger.warning("AppAttest: device registered", category: .security)
                return
            } catch {
                lastError = error
                guard isTransient(error), attempt < maxRegisterAttempts else { throw error }
                SecureLogger.warning("AppAttest: register attempt \(attempt) failed, retrying — \(error.localizedDescription)", category: .security)
                // Linear backoff between POST retries; attestation blob is reused unchanged.
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
            }
        }
        throw lastError
    }

    /// Transient = worth retrying the POST with the same blob. Everything else (auth,
    /// rate-limit, decode, unknown) is treated as give-up and retried on the next login.
    private func isTransient(_ error: Error) -> Bool {
        guard let net = error as? NetworkError else { return false }
        switch net {
        case .serverError, .timeout, .noInternet:
            return true
        default:
            return false
        }
    }
}
