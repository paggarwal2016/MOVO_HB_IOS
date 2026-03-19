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
    @Published var context: String = ""
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
    
    //MARK: - Send OTP
    
    func sendOTP() async throws {
        guard state != .loading else { return }
        state = .loading
        
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(phoneNumber: phoneNumber, context: context)
            )
            state = .otpSent
            showOTP = true
        } catch {
            state = .idle
            throw error
        }
    }
    
    //MARK: - Validate OTP
    
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
    
    func completeOTPVerification(code: String, appState: AppState) async {
        do {
            let response = try await validateOTP(code: code)
            
            try await sessionManager.startSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                appState: appState
            )
            
            await kycManager.configureSDK(officeId: AppConfig.officeId)
            
            appState.otpVerified = true
            if appState.context == PhoneFlowType.login.rawValue {
                appState.flow = .home
            } else {
                appState.flow = .setupPasscode
            }
            reset()
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


extension AuthViewModel { // TODO: - Testing checking
    
    // ── Entry point ───────────────────────────────────────────────────────────
    func enrollRSASilently(appState: AppState) async {
        guard !isEnrolling else {
            SecureLogger.warning("enrollRSASilently already in progress — skipping", category: .auth)
            return
        }
        isEnrolling = true
        defer { isEnrolling = false }
        
        if RSAKeyManager.isRegistered() {
            SecureLogger.info("Already enrolled — calling loginWithRSA", category: .auth)
            await loginWithRSA(appState: appState)
        } else {
            SecureLogger.info("Not enrolled — starting enroll flow", category: .auth)
            await runEnrollFlow(appState: appState)
        }
    }
    
    // ── Enroll flow ───────────────────────────────────────────────────────────
    private func runEnrollFlow(appState: AppState) async {
        
        let keyResult = await Task.detached(priority: .background) {
            RSAKeyManager.generateKeyPair()
        }.value
        
        switch keyResult {
        case .failure(let error):
            SecureLogger.error("generateKeyPair failed: \(error.errorDescription ?? "")", category: .auth)
            return
            
        case .success(let publicKey):
            let enrolled = await postEnrollWithRetry(
                request: RSAEnrollRequest(publicKey: publicKey,
                                          deviceId: await DeviceManager.shared.deviceID())
            )
            guard enrolled else {
                SecureLogger.error("Enroll failed — aborting", category: .auth)
                return
            }
            
            SecureLogger.info("Enroll success — calling loginWithRSA", category: .auth)
            await loginWithRSA(appState: appState, fromEnrollment: true)
        }
    }
    
    // ── POST /rsa with retry ──────────────────────────────────────────────────
    @discardableResult
    private func postEnrollWithRetry(request: RSAEnrollRequest) async -> Bool {
        for attempt in 1...2 {
            SecureLogger.info("POST /rsa attempt \(attempt)", category: .auth)
            
            let success = await postEnroll(request: request)
            
            if success {
                SecureLogger.info("POST /rsa succeeded on attempt \(attempt)", category: .auth)
                return true
            }
            
            SecureLogger.error("POST /rsa attempt \(attempt) failed", category: .auth)
            
            if attempt < 2 {
                SecureLogger.info("Retrying POST /rsa in 1s…", category: .auth)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        RSAKeyManager.deleteKey()
        SecureLogger.error("POST /rsa failed after 2 attempts — key deleted", category: .auth)
        return false
    }
    
    private func postEnroll(request: RSAEnrollRequest) async -> Bool {
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.enrollRSA(request: request)
            )
            return true // normal JSON success
        } catch NetworkError.decodingError {
            // 2xx passed in NetworkService — only decode failed (bare `true` body)
            SecureLogger.info("POST /rsa decode failed on 2xx — treating bare `true` as success", category: .auth)
            return true
        } catch {
            SecureLogger.error("POST /rsa error: \(error.localizedDescription)", category: .auth)
            return false
        }
    }
    
    // ── POST /auth/token-rsa + start session ──────────────────────────────────
    private func tokenRSAAndStartSession(signedMessage: String, appState: AppState) async {
        let deviceId = await DeviceManager.shared.deviceID()
        do {
            let response: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: signedMessage,
                    deviceId: deviceId
                ))
            )
            try await sessionManager.startSession(
                accessToken:  response.accessToken,
                refreshToken: response.refreshToken,
                appState:     appState
            )
            SecureLogger.info("tokenRSA success — session started", category: .auth)
        } catch {
            SecureLogger.error("tokenRSA failed: \(error.localizedDescription)", category: .auth)
            //TODO: - alertManager.showError("Biometric login failed. Please log in with your phone number.")
        }
    }
    
    func loginWithRSA(appState: AppState, fromEnrollment: Bool = false) async {
        guard !isEnrolling || fromEnrollment else {
            SecureLogger.warning("loginWithRSA skipped — enrollment in progress", category: .auth)
            return
        }
        
        let deviceId  = await DeviceManager.shared.deviceID()
        let challenge = RSAKeyManager.buildChallenge(deviceId: deviceId)
        
        switch RSAKeyManager.sign(challenge: challenge, reason: "Authenticate to access MovoCash") {
        case .failure(let error):
            SecureLogger.error("sign failed: \(error)", category: .auth)
            if error == .keyNotFound && !fromEnrollment {
                await runEnrollFlow(appState: appState)
            }
            return
            
        case .success(let signedMessage):
            SecureLogger.info("sign success — calling tokenRSA", category: .auth)
            await tokenRSAAndStartSession(signedMessage: signedMessage, appState: appState)
        }
    }
}


//MARK: - AuthState

enum AuthState: Equatable {
    case idle
    case loading
    case otpSent
    case verified
    case success
    case error(String)
}
