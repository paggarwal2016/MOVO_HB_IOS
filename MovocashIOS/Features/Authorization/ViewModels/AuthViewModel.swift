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
    
    func validateOTP(code: String) async throws -> RefreshTokenResponse  {
        guard state != .loading else { throw ModelError.alreadyLoading }
        state = .loading
        
        do {
            let response: RefreshTokenResponse = try await network.request(
                AuthAPI.tokenSMS(phoneNumber: phoneNumber, code: code)
            )
            self.state = .verified
            reset()
            return response
        } catch {
            state = .idle
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
            let destination: AuthFlow = context == .login ? .home : .setupPasscode
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

    // ── Entry point ───────────────────────────────────────────────────────────
    func enrollRSASilently(appState: AppState) async {
        guard !isEnrolling else {
            SecureLogger.warning("enrollRSASilently already in progress — skipping", category: .auth)
            return
        }
        isEnrolling = true
        defer { isEnrolling = false }
        await performRSAEnrollAndLogin(appState: appState)
    }

    private func performRSAEnrollAndLogin(appState: AppState) async {
        let deviceId = await DeviceManager.shared.deviceID()

        // Phase 1 — key generation and nonce fetch are independent: run concurrently
        async let keyResultAsync = Task.detached(priority: .background) {
            await RSAKeyManager.generateKeyPair()
        }.value
        async let nonceResultAsync: RSANonceResponse = network.request(
            AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId))
        )

        let keyResult: Result<String, RSAKeyAuthError>
        let nonceResponse: RSANonceResponse
        do {
            (keyResult, nonceResponse) = try await (keyResultAsync, nonceResultAsync)
        } catch {
            SecureLogger.error("biometric login failed: \(error.localizedDescription)", category: .auth)
            return
        }
        SecureLogger.info("nonce fetched successfully", category: .auth)

        let publicKey: String
        switch keyResult {
        case .failure(let error):
            SecureLogger.error("RSA key generation failed: \(error.localizedDescription)", category: .auth)
            return
        case .success(let key):
            publicKey = key
        }

        // Phase 2 — enroll key (server must have public key before it can verify tokenRSA)
        do {
            let _: Bool = try await network.request(
                AuthAPI.enrollRSA(request: RSAEnrollRequest(publicKey: publicKey, deviceId: deviceId))
            )
            SecureLogger.info("RSA key enrolled successfully", category: .auth)
        } catch {
            RSAKeyManager.deleteKey()   // keep local/server in sync on failure
            SecureLogger.error("RSA enrollment failed: \(error.localizedDescription)", category: .auth)
            return
        }

        // Phase 3 — sign nonce, get token, start session
        do {
            let _: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: nonceResponse.nonce,
                    deviceId: deviceId
                ))
            )
//            try await sessionManager.startSession(
//                accessToken: response.accessToken,
//                refreshToken: response.refreshToken,
//                appState: appState
//            )
            SecureLogger.info("tokenRSA success — session started", category: .auth)
        } catch {
            SecureLogger.error("biometric login failed: \(error.localizedDescription)", category: .auth)
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
