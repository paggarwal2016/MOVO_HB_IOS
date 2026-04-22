//
//  AuthViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var state: AuthState = .idle
    @Published var showOTP: Bool = false
    @Published var phoneNumber: String = ""
    @Published var phoneDisplayText: String = ""
    @Published var context: PhoneFlowType?
    private var isEnrolling = false
    
    private let network: NetworkServiceProtocol
    private let keychain: KeychainManagerProtocol
    private let authManager: AuthManagerProtocol
    private let sessionManager: SessionManager
    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol
    private let analytics: AnalyticsTracking

    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        authManager: AuthManagerProtocol,
        sessionManager: SessionManager,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking
    ) {
        self.network = network
        self.keychain = keychain
        self.authManager = authManager
        self.sessionManager = sessionManager
        self.kycManager = kycManager
        self.alertManager = alertManager
        self.analytics = analytics
    }
    
    // MARK: - Send OTP
    
    func sendOTP() async throws {
        guard state != .loading else { return }
        state = .loading
        
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(phoneNumber: phoneNumber, context: context?.rawValue ?? "")
            )
            state = .otpSent
            showOTP = true
        } catch {
            state = .idle
            throw error
        }
    }
    
    // MARK: - Validate OTP
    
    func validateOTP(code: String) async throws -> RefreshTokenResponse {
        guard state == .idle || state == .otpSent else { throw ModelError.alreadyLoading }
        state = .loading

        let phone = phoneNumber  // capture before suspend point

        do {
            let response: RefreshTokenResponse = try await network.request(
                AuthAPI.tokenSMS(phoneNumber: phone, code: code)
            )
            await MainActor.run { self.state = .verified }
            return response
        } catch {
            await MainActor.run { self.state = .idle }
            throw error
        }
    }
    
    // MARK: - Complete OTP Verification Flow
    
    func completeOTPVerification(code: String, appState: AppState, onNavigate: @escaping (AuthFlow) -> Void) async {
        analytics.trackLoginAttempt(method: .otp)
        do {
            let response = try await validateOTP(code: code)

            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )

            analytics.trackLogin(method: .otp)
            try await kycManager.configureSDK(officeId: AppConfig.officeId)
            let destination: AuthFlow = context == .login ? .home : .signupDetails
            reset()
            onNavigate(destination)
        } catch {
            analytics.trackLoginFailed(method: .otp, errorCode: error.localizedDescription)
            alertManager.showError(error.localizedDescription)
        }
    }
    
    // MARK: - Phone Input Formatting
    
    private var phonePreviousText: String = ""
    
    func handlePhoneInput(_ newValue: String) {
        let isDeleting = newValue.count < phonePreviousText.count
        var digits = PhoneFormatter.raw(newValue)
        
        if digits.count > 10 {
            phoneDisplayText = phonePreviousText
            return
        }
        
        if isDeleting && PhoneFormatter.raw(phonePreviousText) == digits {
            digits = String(digits.dropLast())
        }
        
        let formatted = PhoneFormatter.formatted(digits)
        
        phoneDisplayText = formatted
        phoneNumber = digits
        phonePreviousText = formatted
    }
    
    // MARK: - Submit Phone Number
    
    func submitPhoneNumber(appState: AppState) async {
        let phone = PhoneNumberValidator.sanitize(phoneNumber)
        
        guard PhoneNumberValidator.isValidUSNumber(phone) else {
            alertManager.showError("Enter a valid phone number")
            return
        }
        
        phoneNumber = PhoneNumberValidator.normalize(phone)
        context = appState.context
        
        do {
            try await sendOTP()
            appState.flow = .otp
        } catch {
            alertManager.showError(error.localizedDescription)
        }
    }
    
    func reset() {
        phoneNumber = ""
        phoneDisplayText = ""
    }
}

// MARK: - RSA Biometric Auth

extension AuthViewModel {

    // ── Enroll: POST /rsa ─────────────────────────────────────────────────────
    // Called once when the user enables Face ID / biometric login.
    func enrollRSA() async {
        guard !isEnrolling else {
            SecureLogger.warning("enrollRSA already in progress — skipping", category: .auth)
            return
        }
        isEnrolling = true
        defer { isEnrolling = false }

        let deviceId = await DeviceManager.shared.deviceID()

        do {
            // Generate biometric-protected RSA key pair on a background thread
            let keyTask = Task.detached(priority: .background) {
                try await RSAKeyManager.shared.createKeyPair()
            }
            let publicKey: String = try await keyTask.value

            // POST /rsa — register public key with the server
            let _: Bool = try await network.request(
                AuthAPI.enrollRSA(request: RSAEnrollRequest(publicKey: publicKey, deviceId: deviceId))
            )
            SecureLogger.info("RSA key enrolled successfully", category: .auth)
        } catch {
            RSAKeyManager.shared.deleteKeyPair()   // keep local/server in sync on failure
            SecureLogger.error("RSA enrollment failed: \(error.localizedDescription)", category: .auth)
        }
    }

    // ── Login: GET /rsa/nonce → sign → POST /auth/token-rsa ──────────────────
    // Returns true on success. Caller unlocks the app silently after success.
    @discardableResult
    func loginWithBiometric(appState: AppState) async -> Bool {
        guard RSAKeyManager.shared.keysExist() else {
            SecureLogger.info("RSA keys not enrolled — skipping biometric server login", category: .auth)
            return false
        }

        let deviceId = await DeviceManager.shared.deviceID()

        do {
            // Step 1 — GET /rsa/nonce
            let nonceResponse: RSANonceResponse = try await network.request(
                AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId))
            )
            SecureLogger.info("nonce fetched successfully", category: .auth)

            // Step 2 — sign nonce (triggers Face ID prompt via biometric-protected key)
            let signedMessage = try RSAKeyManager.shared.createSignature(
                payload: nonceResponse.nonce,
                promptMessage: "Sign in with Face ID"
            )

            // Step 3 — POST /auth/token-rsa
            let response: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: signedMessage,
                    deviceId: deviceId
                ))
            )

            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )
            SecureLogger.info("tokenRSA success — session started", category: .auth)
            // Biometric login is only available to returning users who completed KYC.
            // Restore the flag cleared on logout and navigate to the dashboard.
            UserDefaults.standard.set(true, forKey: "kycCompleted")
            appState.flow = .home
            return true
        } catch {
            SecureLogger.error("biometric login failed: \(error.localizedDescription)", category: .auth)
            return false
        }
    }
}

// MARK: - AuthState

enum AuthState: Equatable {
    case idle
    case loading
    case otpSent
    case verified
    case success
    case error(String)
}
