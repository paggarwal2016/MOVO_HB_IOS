//
//  SessionManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Session Restore Result

enum SessionRestoreResult {
    /// Tokens found and loaded — proceed to home.
    case restored
    /// No tokens in keychain — user has never logged in or explicitly logged out.
    case notLoggedIn
    /// Keychain is temporarily locked (device rebooted, not yet unlocked).
    /// Tokens exist — do not present login, show a retry prompt instead.
    case keychainLocked
}

@MainActor
final class SessionManager: ObservableObject {

    private var logoutTask: Task<Void, Never>?
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
        try await storeTokens(
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
    ) async throws {

        try await keychain.save(
            accessToken,
            for: "access_token",
            protection: .backgroundSafe
        )

        try await keychain.save(
            refreshToken,
            for: "refresh_token",
            protection: .backgroundSafe
        )
    }

    // MARK: - Restore Session

    func restoreSession(appState: AppState) async -> SessionRestoreResult {
        do {
            let accessToken  = try await keychain.get("access_token",  biometricPrompt: nil)
            let refreshToken = try await keychain.get("refresh_token", biometricPrompt: nil)

            guard !accessToken.isEmpty, !refreshToken.isEmpty else {
                return .notLoggedIn
            }

            if isAccessTokenExpired(accessToken) {
                // Token is stale — load it anyway so NetworkService's automatic
                // 401-refresh flow can exchange the refresh token on the first request.
                SecureLogger.warning("Access token expired on restore — refresh will occur on first request", category: .auth)
            }

            await authManager.updateAccessToken(accessToken)
            try await kycManager.configureSDK(officeId: AppConfig.officeId)
            appState.isAuthenticated = true
            return .restored

        } catch KeychainError.interactionNotAllowed {
            // Device rebooted and has not been unlocked yet — tokens exist but are
            // temporarily inaccessible. Do NOT treat this as "not logged in".
            SecureLogger.warning("Keychain locked on session restore — device not yet unlocked since boot", category: .auth)
            return .keychainLocked

        } catch KeychainError.itemNotFound {
            SecureLogger.info("No session tokens found — user not logged in", category: .auth)
            return .notLoggedIn

        } catch {
            SecureLogger.error("Unexpected keychain error on session restore: \(error.localizedDescription)", category: .auth)
            return .notLoggedIn
        }
    }

    // MARK: - JWT Expiry
    /// Decodes the JWT payload (no signature verification — server does that).
    /// Returns true when the `exp` claim is in the past, the token is malformed,
    /// or the expiry is suspiciously far in the future (possible token injection).
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

        let now = Date().timeIntervalSince1970

        // Sanity check: a legitimate JWT should never expire more than 24 hours out.
        // An exp beyond this window is suspicious — could indicate a tampered token
        // injected into local storage. Force a refresh rather than trusting the claim.
        let twentyFourHours: TimeInterval = 24 * 60 * 60
        if exp > now + twentyFourHours {
            SecureLogger.warning(
                "JWT exp is suspiciously far in the future — forcing token refresh",
                category: .security
            )
            return true
        }

        // 30-second buffer guards against clock skew on slow networks
        return now >= exp - 30
    }

    // MARK: - Logout with Confirmation

    func logoutWithConfirmation(appState: AppState, onLockout: @escaping () -> Void) {
        alertManager.showConfirmation(
            title: "Log Out",
            message: "Are you sure you want to log out?",
            onConfirm: { [weak self] in
                guard let self else { return }
                logoutTask?.cancel()
                logoutTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.logout(appState: appState)
                    onLockout()
                }
            },
            onCancel: nil
        )
    }

    // MARK: - Logout
    func logout(appState: AppState) async {

        await authManager.clearSession()
        await PushManager.shared.deleteTokenOnLogout()

        do {
            try await keychain.delete("access_token")
            try await keychain.delete("refresh_token")
        } catch {
            SecureLogger.error("Failed to delete tokens on logout: \(error.localizedDescription)", category: .auth)
        }

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
        appState.context = nil
        appState.otpVerified = false
        appState.isAuthenticated = false
        appState.flow = .choice
        RSAKeyManager.deleteKey() // Ensures biometric re-enrollment on next login
    }
}
