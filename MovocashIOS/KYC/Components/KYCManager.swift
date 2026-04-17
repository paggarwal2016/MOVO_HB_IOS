//
//  KYCManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 27/02/26.
//

import Foundation
import MobileBankingSDK
import UIKit
import SwiftUI

// MARK: - KYCManager Protocol

@MainActor
protocol KYCManagerProtocol {
    func configureSDK(officeId: String) async throws
    func start() async throws -> User
    func clearSession()
    func updateToken(_ token: String)
}

// MARK: - KYCManager

@MainActor
final class KYCManager: KYCManagerProtocol, TokenRefreshable {
    
    static let shared = KYCManager(
        network: NetworkService.shared,
        keychain: KeychainManager.shared
    )

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    private let analytics: AnalyticsTracking
    private weak var presenter: UIViewController?

    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.keychain = keychain
        self.analytics = analytics ?? AnalyticsManager.shared
    }
    
    // MARK: - Configure SDK
    func configureSDK(officeId: String) async throws {
        
        SecureLogger.info("Starting KYC configuration", category: .kyc)
        
        let token = try await freshAccessToken()
        
#if DEBUG
        let verboseLogs = true
#else
        let verboseLogs = false
#endif
        
        MobileBankingSDK.configure(
            authToken: token,
            baseUrl: AppConfig.sdkURL,
            officeId: officeId,
            theme: makeKYCTheme(),
            enableVerboseLogs: verboseLogs
        )
        
        SecureLogger.info("KYC SDK configured", category: .kyc)
    }
    
    // MARK: - Update Token (If Refreshed)
    func updateToken(_ token: String) {
        MobileBankingSDK.updateAuthToken(token)
        SecureLogger.info("KYC token updated", category: .kyc)
    }
    
    // MARK: - Clear Session
    func clearSession() {
        MobileBankingSDK.clearSession()
        SecureLogger.info("KYC session cleared", category: .kyc)
    }
    
    // MARK: - Start KYC Flow
    
    func start() async throws -> User {
        
        // configureSDK is called at login / session-restore — the user may
        // reach this screen minutes or hours later. Re-validate here so the
        // SDK never starts with a stale token.
        let validToken = try await freshAccessToken()
        updateToken(validToken)
        
        guard let topVC = UIApplication.topViewController() else {
            throw KYCError.noPresenter
        }
        
        presenter = topVC
        
        return try await withCheckedThrowingContinuation { continuation in
            
            var resumed = false
            var successToken: NSObjectProtocol?
            var errorToken: NSObjectProtocol?
            var cancelToken: NSObjectProtocol?
            
            func resumeOnce(_ result: Result<User, Error>, needsDismiss: Bool) {
                guard !resumed else { return }
                resumed = true
                
                cleanup(dismiss: needsDismiss)
                
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            func cleanup(dismiss: Bool) {
                if let t = successToken { NotificationCenter.default.removeObserver(t) }
                if let t = errorToken   { NotificationCenter.default.removeObserver(t) }
                if let t = cancelToken  { NotificationCenter.default.removeObserver(t) }
                if dismiss { dismissPresenter() }
            }
            
            func dismissPresenter() {
                Task { @MainActor in
                    self.presenter?.dismiss(animated: true)
                    self.presenter = nil
                }
            }
            
            // SUCCESS — SDK dismisses its own UI, no manual dismiss needed
            successToken = NotificationCenter.default.addObserver(
                forName: .verificationCompleted,
                object: nil,
                queue: .main
            ) { notification in
                guard let user = notification.object as? User else {
                    resumeOnce(.failure(KYCError.unknown), needsDismiss: false)
                    return
                }
                resumeOnce(.success(user), needsDismiss: false)
            }
            
            // ERROR — SDK may not dismiss, force dismiss
            errorToken = NotificationCenter.default.addObserver(
                forName: .scannerError,
                object: nil,
                queue: .main
            ) { notification in
                if let error = notification.object as? Error {
                    resumeOnce(.failure(KYCError.sdkError(error.localizedDescription)), needsDismiss: true)
                } else {
                    resumeOnce(.failure(KYCError.unknown), needsDismiss: true)
                }
            }
            
            // CANCELLED — user tapped cancel on failed-verification screen
            cancelToken = NotificationCenter.default.addObserver(
                forName: .verificationCanceled,
                object: nil,
                queue: .main
            ) { _ in
                resumeOnce(.failure(KYCError.cancelled), needsDismiss: true)
            }
            
            MobileBankingSDK.startKyc(presentingViewController: topVC)
        }
    }
    
    
    // MARK: - Token Management
    
    /// Returns a valid access token for the KYC SDK.
    ///
    /// Flow:
    /// - Reads current token from Keychain.
    /// - Decodes the JWT `exp` claim locally — no network call on the happy path.
    /// - Token valid → returns it immediately.
    /// - Token expired or within 60-second buffer → delegates to `TokenRefreshable.performTokenRefresh()`.
    private func freshAccessToken() async throws -> String {
        guard let current = try? await keychain.get("access_token", biometricPrompt: nil),
              !current.isEmpty else {
            analytics.log(AnalyticsEvent.kycStepFailed, params: [
                AnalyticsParam.kycStep: KYCStep.idVerified.rawValue,
                AnalyticsParam.errorCode: "missing_token"
            ])
            SecureLogger.error("No access token in keychain — aborting KYC", category: .kyc)
            throw KYCError.notConfigured
        }
        
        guard needsTokenRefresh(current) else {
            return current
        }
        
        SecureLogger.info("Token near expiry — refreshing before KYC", category: .kyc)
        
        do {
            let fresh = try await performTokenRefresh()
            analytics.log(AnalyticsEvent.tokenRefreshed, params: [
                AnalyticsParam.reason: "kyc_proactive_refresh"
            ])
            SecureLogger.info("Token refreshed successfully for KYC", category: .kyc)
            return fresh
        } catch {
            analytics.log(AnalyticsEvent.kycStepFailed, params: [
                AnalyticsParam.kycStep: KYCStep.idVerified.rawValue,
                AnalyticsParam.errorCode: "token_refresh_failed"
            ])
            SecureLogger.error("Token refresh failed before KYC: \(error.localizedDescription)", category: .kyc)
            throw KYCError.notConfigured
        }
    }
    
    // MARK: - Theme
    // backgroundGradient    : Back theme
    // accentColor           : Try again, icon Disclaimer
    // labelProps
    // primaryTextColor      : look correct, first, last, let's confirm
    // secondaryTextColor    : first, last, title color
    // buttonProps
    // color                 : Looks good!, Next button, Get Started
    // textColor             : action button color
    // inputProps
    // backgroundColor       : input field background color
    // textColor             : input field text color
    // placeholderColor      : SSN placeholder color
    // borderColor           : corner border color
    
    private func makeKYCTheme() -> Theme {
        
        return Theme(
            backgroundGradient: [
                Color.background,
                Color.background
            ],
            accentColor: .white,
            labelProps: LabelProps(
                primaryTextColor: Color.primaryText,
                secondaryTextColor: Color.secondaryText,
                titleFont: .monospacedSystemFont(ofSize: 28, weight: .bold),
                bodyFont:  .monospacedSystemFont(ofSize: 17, weight: .regular),
                inputLabelFont: .monospacedSystemFont(ofSize: 14, weight: .medium)
            ),
            buttonProps: ButtonProps(
                color: Color.accent1,
                textColor: .white,
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 18, weight: .bold)
            ),
            inputProps: InputProps(
                backgroundColor: Color.inputBackground,
                textColor: Color.inputText,
                placeholderColor: Color.inputPlaceholder,
                borderColor: .white,
                borderWidth: 1.5,
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 16, weight: .regular)
            )
        )
    }
}


