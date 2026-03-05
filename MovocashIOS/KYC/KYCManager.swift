//
//  KYCManager.swift
//  MovocashIOS
//
//  Created by Vinu on 27/02/26.
//

import Foundation
import MobileBankingSDK
import UIKit
import SwiftUI

@MainActor
final class KYCManager {
    
    static let shared = KYCManager()
    private init() {}
    
    private var isConfigured = false
    private weak var presenter: UIViewController?
    
    // MARK: - Configure SDK
    func configureSDK(officeId: String) async {
        guard !isConfigured else { return }
        
        SecureLogger.info("Starting KYC configuration", category: .kyc)
        
        guard let token = await AuthManager.shared.getAccessToken() else {
            SecureLogger.error("Missing access token", category: .kyc)
            return
        }
        
        let baseURL = AppConfig.baseURL.absoluteString
        
        MobileBankingSDK.configure(
            authToken: token,
            baseUrl: baseURL,
            officeId: officeId,
            theme: makeKYCTheme(),
            enableVerboseLogs: true
        )
        
        isConfigured = true
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
        
        guard isConfigured else {
            throw KYCError.notConfigured
        }
        
        guard let topVC = UIApplication.topViewController() else {
            throw KYCError.noPresenter
        }
        
        presenter = topVC
        
        return try await withCheckedThrowingContinuation { continuation in
            
            var resumed = false
            
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
                NotificationCenter.default.removeObserver(self)
                dismiss()
            }
            
            func dismiss() {
                Task { @MainActor in
                    self.presenter?.dismiss(animated: true)
                    self.presenter = nil
                }
            }
            
            // SUCCESS
            NotificationCenter.default.addObserver(
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
            NotificationCenter.default.addObserver(
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
                AppColors.background,
                AppColors.background
            ], // Back theme
            
            accentColor: .white, // Try againing and icon Disclaimer
            
            labelProps: LabelProps(
                primaryTextColor: AppColors.primaryText, // look correct, first , last , let's confirm
                secondaryTextColor: AppColors.secondaryText,// first, last, title color
                titleFont: .monospacedSystemFont(ofSize: 28, weight: .bold),
                bodyFont:  .monospacedSystemFont(ofSize: 17, weight: .regular),
                inputLabelFont: .monospacedSystemFont(ofSize: 14, weight: .medium)
            ),
            
            buttonProps: ButtonProps(
                color: AppColors.accent1,// Looks good! and Next button and get Started
                textColor: .white, // action button color
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 18, weight: .bold)
            ),
            
            inputProps: InputProps(
                backgroundColor: AppColors.inputBackground, // input field background color
                textColor: AppColors.inputText, // input field text color
                placeholderColor: AppColors.inputPlaceholder, // SSN placeholder color
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

