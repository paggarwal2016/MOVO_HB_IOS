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
    private let keychain: KeychainManagerProtocol
    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol
    private let analytics: AnalyticsTracking
    private let network: NetworkServiceProtocol

    init(
        keychain: KeychainManagerProtocol,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking,
        network: NetworkServiceProtocol
    ) {
        self.keychain = keychain
        self.kycManager = kycManager
        self.alertManager = alertManager
        self.analytics = analytics
        self.network = network
    }

    // MARK: - Start Session
    func startSession(
        accessToken: String,
        appState: AppState
    ) async throws {

        // Store securely — Keychain is the single source of truth
        try await storeTokens(
            accessToken: accessToken
        )

        // Update UI state
        appState.isAuthenticated = true
        
        analytics.identifyUser(from: accessToken)
    }

    // MARK: - Store Tokens
    func storeTokens(
        accessToken: String
    ) async throws {

        try await keychain.save(
            accessToken,
            for: "access_token",
            protection: .backgroundSafe
        )
    }

    // MARK: - Restore Session

    func restoreSession(appState: AppState) async -> SessionRestoreResult {
        do {
            let accessToken  = try await keychain.get("access_token",  biometricPrompt: nil)

            guard !accessToken.isEmpty else {
                return .notLoggedIn
            }

            if isAccessTokenExpired(accessToken) {
                // Token is stale — load it anyway so NetworkService's automatic
                // 401-refresh flow can exchange the refresh token on the first request.
                SecureLogger.warning("Access token expired on restore — refresh will occur on first request", category: .auth)
            }

            try await kycManager.configureSDK(officeId: AppConfig.officeId)
            appState.isAuthenticated = true
            analytics.identifyUser(from: accessToken)
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
        guard
            let payload = JWTDecoder.decodePayload(token),
            let exp = payload["exp"] as? TimeInterval
        else { return true }

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
        _ = try? await network.request(AuthAPI.logout) as SuccessResponse
        analytics.trackLogout()
        analytics.clearIdentity()
        await PushManager.shared.deleteTokenOnLogout()

        do {
            try await keychain.delete("access_token")
        } catch {
            SecureLogger.error("Failed to delete tokens on logout: \(error.localizedDescription)", category: .auth)
        }

        kycManager.clearSession()

        resetAppState(appState)
    }

    // MARK: - Force Logout
    func forceLogout(appState: AppState) async {
        analytics.trackSessionExpired()
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
        // RSA keys are intentionally kept across logout so the biometric login
        // button re-appears on ChoiceScreen. Keys are only cleared when the user
        // explicitly disables biometrics in Settings or the server rejects the key.
        UserDefaults.standard.removeObject(forKey: "kycCompleted")
    }
}
