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

// MARK: - KYC Result

enum KYCResult {
    case success(User)
    case failed(Error)
}

// MARK: - KYC Errors

enum KYCError: LocalizedError {
    case notConfigured
    case noViewController
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "KYC SDK is not configured"
        case .noViewController:
            return "Unable to present KYC screen"
        case .timeout:
            return "KYC process timed out"
        case .unknown:
            return "An unknown KYC error occurred"
        }
    }
}

@MainActor
final class KYCManager {
    
    static let shared = KYCManager()
    private init() {}
    
    private var isConfigured = false
    private let timeoutSeconds: UInt64 = 120
    private weak var currentPresenter: UIViewController?
    
    // MARK: - Configure SDK
    
    func configureSDK() async {
        
        SecureLogger.info("Starting KYC configuration", category: .kyc)
        
        guard let token = await AuthManager.shared.getAccessToken() else {
            SecureLogger.error("Missing access token", category: .kyc)
            return
        }
        
        let baseURL = AppConfig.baseURL.absoluteString
        
        MobileBankingSDK.configure(authToken: token, baseUrl: baseURL, theme: makeKYCTheme(), enableVerboseLogs: true)
        
        isConfigured = true
        SecureLogger.info("KYC SDK configured successfully", category: .kyc)
    }
    
    func updateToken(_ token: String) {
        MobileBankingSDK.updateAuthToken(token)
        SecureLogger.info("KYC token updated", category: .kyc)
    }
    
    func clearSession() {
        MobileBankingSDK.clearSession()
        SecureLogger.info("KYC session cleared", category: .kyc)
    }
    
    // MARK: - Start KYC Flow
    
    func startKYC() async -> KYCResult {
        
        guard isConfigured else {
            SecureLogger.error("KYC not configured", category: .kyc)
            return .failed(KYCError.notConfigured)
        }
        
        guard let presentingVC = UIApplication.topViewController() else {
            return .failed(KYCError.noViewController)
        }
        
        currentPresenter = presentingVC
        
        SecureLogger.info("Starting KYC flow", category: .kyc)
        
        return await withCheckedContinuation { continuation in
            
            var successObserver: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            var hasResumed = false
            
            func resumeOnce(_ result: KYCResult) {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: result)
            }
            
            func cleanup() {
                if let successObserver {
                    NotificationCenter.default.removeObserver(successObserver)
                }
                if let errorObserver {
                    NotificationCenter.default.removeObserver(errorObserver)
                }
            }
            
            func dismissSDK() {
                Task { @MainActor in
                    self.currentPresenter?.dismiss(animated: true)
                    self.currentPresenter = nil
                }
            }
            
            // MARK: - Success Observer
            
            successObserver = NotificationCenter.default.addObserver(
                forName: .verificationCompleted,
                object: nil,
                queue: .main
            ) { notification in
                
                cleanup()
                
                guard let user = notification.object as? User else {
                    SecureLogger.error("KYC success but User missing", category: .kyc)
                    resumeOnce(.failed(KYCError.unknown))
                    return
                }
                
                SecureLogger.info("KYC success for userId: \(user)", category: .kyc)
                
                dismissSDK()
                resumeOnce(.success(user))
            }
            
            // MARK: - Error Observer
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .scannerError,
                object: nil,
                queue: .main
            ) { notification in
                cleanup()
                
                let error = notification.object as? Error ?? KYCError.unknown
                print("error =",error)
                SecureLogger.error("KYC error: \(error.localizedDescription)", category: .kyc)
                
                dismissSDK()
                NotificationCenter.default.post(name: .otpFlowCancel, object: nil)
                resumeOnce(.failed(error))
            }
            
            // MARK: - Timeout Protection
            
            Task {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                
                guard !hasResumed else { return }
                
                SecureLogger.error("KYC timeout", category: .kyc)
                
                cleanup()
                dismissSDK()
                NotificationCenter.default.post(name: .otpFlowCancel, object: nil)
                resumeOnce(.failed(KYCError.timeout))
            }
            
            // MARK: - Start SDK
            
            MobileBankingSDK.startKyc(presentingViewController: presentingVC)
        }
    }
    
    // MARK: - // Theme Configure
    
    private func makeKYCTheme() -> Theme {
        
        let primary = UIColor(red: 18/255, green: 31/255, blue: 56/255, alpha: 1)
        let accent  = UIColor(red: 77/255, green: 163/255, blue: 255/255, alpha: 1) // fintech blue
        
        return Theme(
            backgroundGradient: [
                primary,
                UIColor(
                    red: 10/255,
                    green: 18/255,
                    blue: 36/255,
                    alpha: 1
                )
            ],
            
            accentColor: accent,
            
            labelProps: LabelProps(
                primaryTextColor: accent,
                secondaryTextColor: UIColor(
                    red: 120/255,
                    green: 150/255,
                    blue: 200/255,
                    alpha: 1
                ),
                titleFont: .monospacedSystemFont(ofSize: 28, weight: .bold),
                bodyFont:  .monospacedSystemFont(ofSize: 17, weight: .regular),
                inputLabelFont: .monospacedSystemFont(ofSize: 14, weight: .medium)
            ),
            
            buttonProps: ButtonProps(
                color: primary,
                textColor: .white,
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 18, weight: .bold)
            ),
            
            inputProps: InputProps(
                backgroundColor: UIColor(
                    red: 20/255,
                    green: 30/255,
                    blue: 55/255,
                    alpha: 1
                ),
                textColor: .white,
                placeholderColor: UIColor(
                    red: 140/255,
                    green: 160/255,
                    blue: 200/255,
                    alpha: 0.8
                ),
                borderColor: accent.withAlphaComponent(0.8),
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
