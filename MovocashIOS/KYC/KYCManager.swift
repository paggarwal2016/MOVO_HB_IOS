//
//  KYCManager.swift
//  MovocashIOS
//
//  Created by Vinu on 27/02/26.
//

import Foundation
import MobileBankingSDK
import UIKit

// MARK: - KYC Result

enum KYCResult {
    case success
    case failed(Error)
}

// MARK: - KYC Manager

final class KYCManager {
    static let shared = KYCManager()
    private init() {}

    private var isConfigured = false

    func configureSDK() async {
        SecureLogger.info("Starting configuration", category: .kyc)

        guard let token = await AuthManager.shared.getAccessToken() else {
            SecureLogger.error("configuration failed: Missing access token", category: .kyc)
            return
        }

        let baseURL = AppConfig.baseURL.absoluteString

        SecureLogger.debug("Using Base URL: \(baseURL)", category: .kyc)

        MobileBankingSDK.configure(authToken: token, baseUrl: baseURL)

        SecureLogger.info("Configured successfully", category: .kyc)

        isConfigured = true
    }

    func updateToken(_ token: String) {
        MobileBankingSDK.updateAuthToken(token)
        SecureLogger.info("update token", category: .kyc)
    }

    func clearSession() {
        MobileBankingSDK.clearSession()
        SecureLogger.info("clear session", category: .kyc)
    }

    // MARK: - Start KYC and Wait for Result

    @MainActor
    func startKYC() async -> KYCResult {

        guard isConfigured else {
            SecureLogger.error("KYC SDK not configured", category: .kyc)
            return .failed(KYCError.notConfigured)
        }

        guard let topVC = UIApplication.topViewController() else {
            SecureLogger.error("No presenting view controller found", category: .kyc)
            return .failed(KYCError.noViewController)
        }

        SecureLogger.info("Starting KYC flow", category: .kyc)

        return await withCheckedContinuation { continuation in
            var successObserver: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?

            // Clean up both observers after either fires
            func removeObservers() {
                if let observer = successObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                if let observer = errorObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }

            // Observe KYC success
            successObserver = NotificationCenter.default.addObserver(
                forName: .verificationCompleted,
                object: nil,
                queue: .main
            ) { _ in
                removeObservers()
                SecureLogger.info("KYC verification completed successfully", category: .kyc)
                continuation.resume(returning: .success)
            }

            // Observe KYC error
            errorObserver = NotificationCenter.default.addObserver(
                forName: .scannerError,
                object: nil,
                queue: .main
            ) { notification in
                removeObservers()
                let error = notification.object as? Error ?? KYCError.unknown
                SecureLogger.error("KYC scanner error: \(error.localizedDescription)", category: .kyc)
                continuation.resume(returning: .failed(error))
            }

            // Present the KYC scanner
            MobileBankingSDK.startKyc(presentingViewController: topVC)
        }
    }
}

// MARK: - KYC Errors

enum KYCError: LocalizedError {
    case notConfigured
    case noViewController
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "KYC SDK is not configured"
        case .noViewController:
            return "Unable to present KYC screen"
        case .unknown:
            return "An unknown KYC error occurred"
        }
    }
}



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
