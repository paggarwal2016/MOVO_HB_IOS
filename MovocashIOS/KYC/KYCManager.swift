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
final class KYCManager: KYCManagerProtocol {

    static let shared = KYCManager(authManager: AuthManager.shared)

    private let authManager: AuthManagerProtocol
    private weak var presenter: UIViewController?

    init(authManager: AuthManagerProtocol) {
        self.authManager = authManager
    }

    // MARK: - Configure SDK
    func configureSDK(officeId: String) async throws {

        SecureLogger.info("Starting KYC configuration", category: .kyc)

        guard let token = await authManager.getAccessToken() else {
            SecureLogger.error("Missing access token — aborting KYC configure", category: .kyc)
            throw KYCError.notConfigured
        }

        let baseURL = AppConfig.baseURL.absoluteString

        #if DEBUG
        let verboseLogs = true
        #else
        let verboseLogs = false
        #endif

        MobileBankingSDK.configure(
            authToken: token,
            baseUrl: baseURL,
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
    
    
    // MARK: - // Theme Configure
    
    private func makeKYCTheme() -> Theme {
        
        return Theme(
            backgroundGradient: [
                Color.background,
                Color.background
            ], // Back theme
            
            accentColor: .white, // Try againing and icon Disclaimer
            
            labelProps: LabelProps(
                primaryTextColor: Color.primaryText, // look correct, first , last , let's confirm
                secondaryTextColor: Color.secondaryText,// first, last, title color
                titleFont: .monospacedSystemFont(ofSize: 28, weight: .bold),
                bodyFont:  .monospacedSystemFont(ofSize: 17, weight: .regular),
                inputLabelFont: .monospacedSystemFont(ofSize: 14, weight: .medium)
            ),
            
            buttonProps: ButtonProps(
                color: Color.accent1,// Looks good! and Next button and get Started
                textColor: .white, // action button color
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 18, weight: .bold)
            ),
            
            inputProps: InputProps(
                backgroundColor: Color.inputBackground, // input field background color
                textColor: Color.inputText, // input field text color
                placeholderColor: Color.inputPlaceholder, // SSN placeholder color
                borderColor: .white, // corner border color
                borderWidth: 1.5,
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 16, weight: .regular)
            )
        )
    }
}


