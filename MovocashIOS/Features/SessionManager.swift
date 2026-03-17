//
//  SessionManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SessionManager: ObservableObject {

    private let authManager: AuthManagerProtocol
    private let keychain: KeychainManagerProtocol
    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol

    init(
        authManager: AuthManagerProtocol,
        keychain: KeychainManagerProtocol,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol
    ) {
        self.authManager = authManager
        self.keychain = keychain
        self.kycManager = kycManager
        self.alertManager = alertManager
    }

    // MARK: - Start Session
    func startSession(
        accessToken: String,
        refreshToken: String,
        appState: AppState
    ) async throws {

        // Update memory token
        await authManager.updateAccessToken(accessToken)

        // Store securely
        try storeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken
        )

        // Update UI state
        appState.isAuthenticated = true
    }

    // MARK: - Store Tokens
    func storeTokens(
        accessToken: String,
        refreshToken: String
    ) throws { 

        try keychain.save(
            accessToken,
            for: "access_token", 
            protection: .backgroundSafe
        )

        try keychain.save(
            refreshToken,
            for: "refresh_token",
            protection: .backgroundSafe
        )
        
    }

    // MARK: - Restore Session
    func restoreSession(appState: AppState) async -> Bool {
        guard let accessToken = try? keychain.get("access_token", biometricPrompt: nil),
              let refreshToken = try? keychain.get("refresh_token", biometricPrompt: nil),
              !accessToken.isEmpty,
              !refreshToken.isEmpty else {
            return false
        }

        if isAccessTokenExpired(accessToken) {
            // Token is stale — load it anyway so NetworkService's automatic
            // 401-refresh flow can exchange the refresh token on the first request.
            SecureLogger.warning("Access token expired on restore — refresh will occur on first request", category: .auth)
        }

        await authManager.updateAccessToken(accessToken)
        appState.isAuthenticated = true
        return true
    }

    // MARK: - JWT Expiry
    /// Decodes the JWT payload (no signature verification — server does that).
    /// Returns true when the `exp` claim is in the past or the token is malformed.
    private func isAccessTokenExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return true }

        // JWT uses base64url encoding — convert to standard base64
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }

        // 30-second buffer guards against clock skew on slow networks
        return Date().timeIntervalSince1970 >= exp - 30
    }

    // MARK: - Logout
    func logout(appState: AppState) async {

        await authManager.clearSession()

        try? keychain.delete("access_token")
        try? keychain.delete("refresh_token")

        kycManager.clearSession()

        resetAppState(appState)
    }

    // MARK: - Force Logout
    func forceLogout(appState: AppState) async {

        await logout(appState: appState)

        alertManager.showError(
            "Session expired. Please login again."
        )
    }

    // MARK: - Reset App State
    private func resetAppState(_ appState: AppState) {
        appState.context = ""
        appState.otpVerified = false
        appState.isAuthenticated = false
        appState.flow = .choice
        RSAKeyManager.deleteKey() // TODO: - Testing checking
    }
}
