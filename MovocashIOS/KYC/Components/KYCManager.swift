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

// MARK: - Protocol

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

    // MARK: Shared
    static let shared = KYCManager(
        network: NetworkService.shared,
        keychain: KeychainManager.shared
    )

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    private let analytics: AnalyticsTracking

    /// Dedicated window that hosts the entire KYC flow.
    /// Isolates the SDK from the SwiftUI UIHostingController so the SDK's
    /// internal alerts never conflict with the main app window hierarchy.
    private var kycWindow: UIWindow?

    // MARK: Init
    init(network: NetworkServiceProtocol, keychain: KeychainManagerProtocol, analytics: AnalyticsTracking? = nil) {
        self.network   = network
        self.keychain  = keychain
        self.analytics = analytics ?? AnalyticsManager.shared
    }
}

// MARK: - KYCManager: SDK Lifecycle

extension KYCManager {

    func configureSDK(officeId: String) async throws {
        SecureLogger.info("Configuring KYC SDK", category: .kyc)

        let token: String
        do {
            token = try await keychain.get("access_token", biometricPrompt: nil)
        } catch {
            SecureLogger.error("Missing access token — aborting KYC configure", category: .kyc)
            analytics.log(AnalyticsEvent.kycStepFailed, params: [AnalyticsParam.errorCode: "missing_token"])
            throw KYCError.notConfigured
        }

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

        SecureLogger.info("KYC SDK configured successfully", category: .kyc)
    }

    func updateToken(_ token: String) {
        MobileBankingSDK.updateAuthToken(token)
        SecureLogger.info("KYC auth token refreshed", category: .kyc)
    }

    func clearSession() {
        MobileBankingSDK.clearSession()
        SecureLogger.info("KYC session cleared", category: .kyc)
    }
}

// MARK: - KYCManager: KYC Flow

extension KYCManager {

    func start() async throws -> User {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw KYCError.noPresenter
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
            var resumed = false

            func resumeOnce(_ result: Result<User, Error>) {
                guard !resumed else { return }
                resumed = true
                
                switch result {
                case .success(let user): continuation.resume(returning: user)
                case .failure(let e):    continuation.resume(throwing: e)
                }
            }

            // Dedicated window — the SDK and all its internal alert presentations
            // are completely isolated from the SwiftUI UIHostingController window,
            // preventing "already presenting" conflicts on cancel/error paths.
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .normal + 1
            self.kycWindow = window

            let wrapper = KYCViewControllerWrapper()
            window.rootViewController = wrapper
            window.makeKeyAndVisible()

            // [weak self] prevents the closure from keeping KYCManager alive
            // after the flow ends; tearDownKYCWindow cleans up the window.
            wrapper.onSuccess = { [weak self] user in
                self?.tearDownKYCWindow()
                resumeOnce(.success(user))
            }
            wrapper.onFailure = { [weak self] error in
                self?.tearDownKYCWindow()
                resumeOnce(.failure(error))
            }
        }
    }

    private func tearDownKYCWindow() {
        kycWindow?.isHidden = true
        kycWindow = nil
    }
}

// MARK: - KYCManager: Theme



private extension KYCManager {

    func makeKYCTheme() -> Theme {
        Theme(
            backgroundGradient: [UIColor(.appBackground),
                                 UIColor(.appBackground)], // Back theme
            
            accentColor: .black, // Try againing and icon Disclaimer
            
            labelProps: LabelProps(
                primaryTextColor: .black, // look correct, first , last , let's confirm
                secondaryTextColor: Color.secondaryText,// first, last, title color
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
                backgroundColor: UIColor(.inputBackground), // input field background color
                textColor: .black, // input field text color
                placeholderColor: Color.inputPlaceholder, // SSN placeholder color
                borderColor: .black, // corner border color
                borderWidth: 1.5,
                cornerRadius: 8,
                font: .monospacedSystemFont(ofSize: 16, weight: .regular)
            )
        )
    }
}

// MARK: - KYCViewControllerWrapper

/// Transparent root VC of the dedicated KYC UIWindow.
/// Presents the MobileBankingSDK KYC flow and owns all four SDK notifications.
/// Because it is the root of its own window, the SDK's internal alert
/// presentations always land here — never on the SwiftUI UIHostingController.
private final class KYCViewControllerWrapper: UIViewController {

    // MARK: Callbacks
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?

    // MARK: State
    private var hasLaunchedKyc = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleCompleted(_:)),    name: .verificationCompleted, object: nil)
        nc.addObserver(self, selector: #selector(handleCanceled(_:)),     name: .verificationCanceled,  object: nil)
        nc.addObserver(self, selector: #selector(handleFailed(_:)),       name: .verificationFailed,    object: nil)
        nc.addObserver(self, selector: #selector(handleScannerError(_:)), name: .scannerError,          object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasLaunchedKyc else { return }
        hasLaunchedKyc = true
        MobileBankingSDK.startKyc(presentingViewController: self, useSdkSuccessUI: false) //true Get started UI is appear
    }

    // deinit must be in the class body — Swift forbids deinit in extensions
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Notification Handlers

    @objc private func handleCompleted(_ notification: Notification) {
        guard let user = notification.object as? User else { return }
        print("user Response", user)
        SecureLogger.info("KYC verificationCompleted", category: .kyc)
        dismissSDKThen { [weak self] in self?.onSuccess?(user) }
    }

    @objc private func handleCanceled(_ notification: Notification) {
        SecureLogger.info("KYC verificationCanceled", category: .kyc)
        dismissSDKThen { [weak self] in self?.onFailure?(KYCError.cancelled) }
    }

    @objc private func handleFailed(_ notification: Notification) {
        let message = (notification.object as? Error)?.localizedDescription
            ?? "Identity verification failed."
        SecureLogger.error("KYC verificationFailed: \(message)", category: .kyc)
        dismissSDKThen { [weak self] in self?.onFailure?(KYCError.sdkError(message)) }
    }

    @objc private func handleScannerError(_ notification: Notification) {
        let message = (notification.object as? NSError)?.localizedDescription
            ?? "Scanner error occurred."
        SecureLogger.error("KYC scannerError: \(message)", category: .kyc)
        dismissSDKThen { [weak self] in self?.onFailure?(KYCError.sdkError(message)) }
    }

    // MARK: Helpers

    /// Dismisses the SDK's presented VC (animated), then fires the callback.
    /// Falls through immediately if no SDK VC is currently presented.
    private func dismissSDKThen(_ completion: @escaping () -> Void) {
        if let sdkVC = presentedViewController {
            sdkVC.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
}
