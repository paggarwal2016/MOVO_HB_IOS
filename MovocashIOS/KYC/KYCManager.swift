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
    func configureSDK(officeId: String) async
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
    func configureSDK(officeId: String) async {

        SecureLogger.info("Starting KYC configuration", category: .kyc)

        guard let token = await authManager.getAccessToken() else {
            SecureLogger.error("Missing access token", category: .kyc)
            return
        }
        
        let baseURL = AppConfig.baseURL.absoluteString
        
        MobileBankingSDK.configure(
            authToken: token,
            baseUrl: baseURL,
            officeId: officeId,
            theme: makeKYCTheme()
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

            func resumeOnce(_ result: Result<User, Error>) {
                guard !resumed else { return }
                resumed = true

                cleanup()

                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            func cleanup() {
                if let t = successToken { NotificationCenter.default.removeObserver(t) }
                if let t = errorToken   { NotificationCenter.default.removeObserver(t) }
                dismiss()
            }

            func dismiss() {
                Task { @MainActor in
                    self.presenter?.dismiss(animated: true)
                    self.presenter = nil
                }
            }

            // SUCCESS
            successToken = NotificationCenter.default.addObserver(
                forName: .verificationCompleted,
                object: nil,
                queue: .main
            ) { notification in

                guard let user = notification.object as? User else {
                    resumeOnce(.failure(KYCError.unknown))
                    return
                }
                resumeOnce(.success(user))
            }

            // ERROR
            errorToken = NotificationCenter.default.addObserver(
                forName: .scannerError,
                object: nil,
                queue: .main
            ) { notification in

                if let error = notification.object as? Error {
                    resumeOnce(.failure(KYCError.sdkError(error.localizedDescription)))
                } else {
                    resumeOnce(.failure(KYCError.unknown))
                }
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

// MARK: - Top View Controller Helper

extension UIApplication {
    
    static func topViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

