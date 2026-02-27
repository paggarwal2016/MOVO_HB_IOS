//
//  KYCManager.swift
//  MovocashIOS
//
//  Created by Vinu on 27/02/26.
//

import Foundation
import MobileBankingSDK
import UIKit

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
        
        SecureLogger.debug("Using Token: \(token)", category: .kyc)
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
    
    // MARK: - Start KYC (SwiftUI Friendly)
    
    func startKYC() {
        
        guard isConfigured else {
            print("KYC SDK not configured")
            return
        }
    
        guard let topVC = UIApplication.topViewController() else { return }
            MobileBankingSDK.startKyc(presentingViewController: topVC)
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
