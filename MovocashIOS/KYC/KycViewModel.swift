
  //KycViewModel.swift
  //MovocashIOS

  //Created by Movo Developer on 23/02/26.


import Foundation
import SwiftUI
import MobileBankingSDK
import BlinkIDUX
import Combine

@MainActor
class KycViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var statusMessage: String = ""
    @Published var isKycCompleted = false
    @Published var errorMessage: String?
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .verificationCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleSuccess(notification: notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .scannerError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleError(notification: notification)
            }
        }
    }
    
    func startKyc() {
        guard let token = KeychainManager.shared.get("accessToken") else { // AuthManager.shared.accessToken
            errorMessage = "Missing access token"
            return
        }
        let baseUrl = AppEnvironment.shared.current.baseURL.absoluteString // AppConfig.baseURL

        
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Unable to find presenting view controller"
            return
        }
        
        let topVC = Self.topViewController(from: rootVC)
        
        KycSdk.startKyc(
            presentingViewController: topVC,
            authToken: token,
            baseUrl: baseUrl,
            theme: createTheme()
        )
    }
    
    private static func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = root as? UINavigationController,
           let visible = nav.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return root
    }

    
    private func handleSuccess(notification: Notification) {
        isLoading = false
        isKycCompleted = true
        statusMessage = "Verification Completed Successfully 🎉"
    }
    
    private func handleError(notification: Notification) {
        isLoading = false
        errorMessage = "Verification Failed"
        statusMessage = "Something went wrong."
    }
    
    private func createTheme() -> Theme {
        
        let labelProps = LabelProps(
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            titleFont: .systemFont(ofSize: 22, weight: .bold),
            bodyFont: .systemFont(ofSize: 16, weight: .regular),
            inputLabelFont: .systemFont(ofSize: 14, weight: .medium)
        )
        
        let buttonProps = ButtonProps(
            color: .systemBlue,
            textColor: .white,
            cornerRadius: 12,
            font: .systemFont(ofSize: 16, weight: .semibold)
        )
        
        let inputProps = InputProps(
            backgroundColor: .white,
            textColor: .black,
            placeholderColor: .gray,
            borderColor: .lightGray,
            borderWidth: 1,
            cornerRadius: 10,
            font: .systemFont(ofSize: 16, weight: .regular)
        )
        
        return Theme(
            backgroundGradient: [.white, .systemGray6],
            accentColor: .systemBlue,
            labelProps: labelProps,
            buttonProps: buttonProps,
            inputProps: inputProps
        )
    }
}










import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return nil
        }
        return UIApplication.getTopViewController(from: root)
    }

    private static func getTopViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let nav = root as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController ?? nav)
        }
        if let tab = root as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController ?? tab)
        }
        return root
    }
}
