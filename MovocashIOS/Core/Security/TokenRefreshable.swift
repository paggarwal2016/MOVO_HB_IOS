//
//  TokenRefreshable.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/04/26.
//

import Foundation

// MARK: - TokenRefreshable

/// Shared token-validation behaviour for any component that must pass a
/// fresh access token to the MobileBankingSDK or a third-party flow before starting.
///
/// Adopters must expose `network` and `keychain` — all validation and
/// refresh logic is provided via default protocol-extension implementations
/// so the logic lives in one place and is fully testable via injection.
@MainActor
protocol TokenRefreshable {
    var network: NetworkServiceProtocol { get }
    var keychain: KeychainManagerProtocol { get }
}

extension TokenRefreshable {

    // MARK: - Needs Refresh

    /// Returns `true` when the token must be refreshed before use.
    ///
    /// Triggers refresh when:
    /// - JWT is malformed or missing the `exp` claim.
    /// - Token expires within the next 60 seconds (proactive buffer for long-running flows).
    /// - `exp` is more than 24 hours in the future (tampered / injected token guard).
    func needsTokenRefresh(_ token: String) -> Bool {
        guard
            let payload = JWTDecoder.decodePayload(token),
            let exp = payload["exp"] as? TimeInterval
        else { return true }

        let now = Date().timeIntervalSince1970

        if exp > now + 24 * 60 * 60 {
            SecureLogger.warning("JWT exp exceeds 24-hour sanity limit — treating as tampered", category: .security)
            return true
        }

        // 60-second proactive buffer — refresh before the flow starts, not during
        return now >= exp - 60
    }

    // MARK: - Perform Refresh

    /// Calls `AuthAPI.tokenAccess`, saves the new token via the injected keychain, and returns it.
    ///
    /// Throws on network failure — callers should map to their domain error
    /// (e.g. `KYCError.notConfigured`, `PlaidLinkError.tokenUnavailable`).
    func performTokenRefresh() async throws -> String {
        let response: RefreshTokenResponse = try await network.request(AuthAPI.tokenAccess)
        try? await keychain.save(
            response.accessToken,
            for: "access_token",
            protection: .backgroundSafe
        )
        return response.accessToken
    }
}
