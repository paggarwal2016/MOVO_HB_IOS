//
//  DeviceSessionManager.swift
//  MovocashIOS
//
//  Owns the X25519 "device session" used by the secure `movo-info` header.
//
//  Lifecycle:
//    • GET /v1/device/config returns the server's X25519 public key
//      (`movoSessionConfig`, 32-byte raw, base64) and a `sessionId`.
//    • The server keeps the matching private key in Redis for 15 minutes of
//      inactivity. When it expires the server can no longer decrypt the blob,
//      so the client re-fetches the config and retries (handled reactively in
//      NetworkService).
//    • Both values are persisted to the Keychain under dedicated keys, kept
//      separate from the RSA `movo-info` path (`movo_session_config` /
//      `auth_session_id`).
//

import Foundation

actor DeviceSessionManager {

    // The singletons (`KeychainManager.shared`, `NetworkService.shared`) are
    // main-actor isolated under the project's default isolation, so they cannot
    // be read from this `static let`'s nonisolated initializer. They are instead
    // referenced inside the `async` methods below — within an `await`, the same
    // way `HeaderProvider` accesses them.
    static let shared = DeviceSessionManager()
    private init() {}

    // Keychain keys — distinct from the RSA movo-info path.
    static let publicKeyKey = "device_session_pubkey"
    static let sessionIdKey  = "device_session_id"

    // MARK: - Config Fetch

    /// Fetches `/device/config` and persists the X25519 public key + sessionId.
    /// Called once lazily on first use, and again by the reactive retry when the
    /// server's 15-minute Redis session has expired.
    func refresh() async throws {
        let info: ConfigureResponse = try await NetworkService.shared.request(AuthAPI.deviceConfig)
        try await KeychainManager.shared.save(info.movoSessionConfig, for: Self.publicKeyKey, protection: .backgroundSafe)
        try await KeychainManager.shared.save(info.sessionId, for: Self.sessionIdKey, protection: .backgroundSafe)
    }

    // MARK: - Header Value

    /// Returns the full `movo-info` value (`<sessionId>.<base64Blob>`) for the
    /// X25519 scheme, fetching a config first if none is cached. Returns `nil`
    /// if the config is unavailable or encryption fails — the request then goes
    /// out without the header (the server responds with a tunable expiry signal,
    /// which the reactive retry uses to re-fetch and retry once).
    func headerValue() async -> String? {
        // Config is fetched only at login (after OTP). No lazy re-fetch here — if it is
        // missing/expired the request goes out without the header and the server-side
        // session-expiry flow handles re-login.
        guard let config = await currentConfig() else {
            SecureLogger.error("secure movo-info: device config unavailable", category: .network)
            return nil
        }

        do {
            // `DeviceInfo`'s Encodable conformance and `DeviceInfo.current` are
            // main-actor isolated, so build + encode the payload on the main actor
            // and hand the resulting (Sendable) Data back to this actor.
            let payload = try await MainActor.run { try JSONEncoder().encode(DeviceInfo.current) }
            let blob = try SealedCryptoService.sealDeviceInfo(payload, serverPublicKeyBase64: config.publicKey)
            return "\(config.sessionId).\(blob)"
        } catch {
            SecureLogger.error("secure movo-info: encryption failed — \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// True when a device-session config (public key + sessionId) is cached.
    /// Used by the login flow to confirm the config is ready before `tokenSMS`.
    func hasConfig() async -> Bool {
        await currentConfig() != nil
    }

    // MARK: - Private

    /// Reads the cached config via the async Keychain API. The synchronous
    /// `getSync` is main-actor isolated and cannot be called from this actor.
    private func currentConfig() async -> (publicKey: String, sessionId: String)? {
        guard let publicKey = try? await KeychainManager.shared.get(Self.publicKeyKey, biometricPrompt: nil),
              !publicKey.isEmpty,
              let sessionId = try? await KeychainManager.shared.get(Self.sessionIdKey, biometricPrompt: nil),
              !sessionId.isEmpty else {
            return nil
        }
        return (publicKey, sessionId)
    }
}
