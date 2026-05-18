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

    // MARK: - Fresh Access Token

    /// Always fetches a fresh access token from the server and saves it to Keychain.
    /// Throws `PlaidLinkError.tokenUnavailable` if the refresh fails.
    func freshAccessToken() async throws -> String {
        return try await performTokenRefresh()
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
