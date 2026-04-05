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
    
    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        authManager: AuthManagerProtocol,
        sessionManager: SessionManager,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol
    ) {
        self.network = network
        self.keychain = keychain
        self.authManager = authManager
        self.sessionManager = sessionManager
        self.kycManager = kycManager
        self.alertManager = alertManager
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
        do {
            let response = try await validateOTP(code: code)

            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )

            await kycManager.configureSDK(officeId: AppConfig.officeId)

            let destination: AuthFlow = context == .login ? .home : .setupPasscode
            reset()
            onNavigate(destination)
        } catch {
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
        await loginWithRSA(appState: appState)
    }

    // ── POST /rsa/nonce + POST /auth/token-rsa ────────────────────────────────
    private func loginWithRSA(appState: AppState) async {
        let deviceId = await DeviceManager.shared.deviceID()

        do {
            let nonceResponse: RSANonceResponse = try await network.request(
                AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId))
            )
            SecureLogger.info("nonce fetched successfully", category: .auth)

            let response: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: nonceResponse.nonce,
                    deviceId: deviceId
                ))
            )
            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )
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
