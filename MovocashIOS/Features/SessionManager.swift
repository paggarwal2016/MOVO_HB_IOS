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

    init(
        authManager: AuthManagerProtocol,
        keychain: KeychainManagerProtocol
    ) {
        self.authManager = authManager
        self.keychain = keychain
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

    // MARK: - Logout
    func logout(appState: AppState) async {

        await authManager.clearSession()

        try? keychain.delete("access_token")
        try? keychain.delete("refresh_token")

        KYCManager.shared.clearSession()

        resetAppState(appState)
    }

    // MARK: - Force Logout
    func forceLogout(appState: AppState) async {

        await logout(appState: appState)

        AlertManager.shared.showError(
            "Session expired. Please login again."
        )
    }

    // MARK: - Reset App State
    private func resetAppState(_ appState: AppState) {
        appState.context = ""
        appState.otpVerified = false
        appState.isAuthenticated = false
        appState.flow = .choice
    }
}
