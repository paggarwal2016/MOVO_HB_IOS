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
    @Published var email: String = ""
    @Published var context: PhoneFlowType?
    private var isEnrolling = false
    
    private let network: NetworkServiceProtocol
    private let keychain: KeychainManagerProtocol
    private let sessionManager: SessionManager
    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol
    private let analytics: AnalyticsTracking
    private let lockManager: AppLockManager

    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        sessionManager: SessionManager,
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking,
        lockManager: AppLockManager
    ) {
        self.network = network
        self.keychain = keychain
        self.sessionManager = sessionManager
        self.kycManager = kycManager
        self.alertManager = alertManager
        self.analytics = analytics
        self.lockManager = lockManager
    }
    
    // MARK: - Send OTP
    
    func sendOTP() async throws {
        guard state != .loading else { return }
        state = .loading
        
        do {
            let response: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(request:
                                        MessengerOTPRequest(phoneNumber: phoneNumber,
                                                            context: context?.rawValue ?? "",
                                                            userAction: "SEND_OTP",
                                                            deviceInfo: .current))
            )
            state = .otpSent
            showOTP = true
            ToastManager.shared.show(
                response.message ?? "OTP sent successfully",
                style: .success,
                position: .bottom
            )
        } catch {
            state = .idle
            throw error
        }
    }
    
    // MARK: - Validate OTP
    
    func validateOTP(code: String) async throws -> AuthTokenSMSResponse {
        guard state != .loading else { throw ModelError.alreadyLoading }
        state = .loading

        do {
            let response: AuthTokenSMSResponse = try await network.request(
                AuthAPI.tokenSMS(request: TokenSMSRequest(
                    phoneNumber: phoneNumber,
                    code: code,
                    userAction: "VERIFY_OTP"
                ))
            )
            await MainActor.run { self.state = .verified }
            return response
        } catch {
            await MainActor.run { self.state = .idle }
            throw error
        }
    }
    
    // MARK: - Complete OTP Verification Flow
    
    func completeOTPVerification(code: String, appState: AppState, onNavigate: @escaping (AuthFlow) async -> Void) async {
        analytics.trackLoginAttempt(method: .otp)
        do {
            // Step 1: Verify OTP → get sessionId
            let otpResponse = try await validateOTP(code: code)
            let sessionId = otpResponse.sessionId

            // Step 2: Persist sessionId to Keychain
            try await keychain.save(sessionId, for: "auth_session_id", protection: .backgroundSafe)

            // Step 3: Exchange sessionId for access + refresh tokens
            let tokenResponse: RefreshTokenResponse = try await network.request(
                AuthAPI.tokenAccess
            )

            try await sessionManager.startSession(
                accessToken: tokenResponse.accessToken,
                appState: appState
            )

            analytics.trackLogin(method: .otp)
            let destination: AuthFlow = context == .login ? .home : .signupDetails
            reset()
            await onNavigate(destination)
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
    
    // MARK: - Send Email OTP

    func sendEmailOTP() async throws {
        guard state != .loading else { return }
        state = .loading
        do {
            let response: SuccessResponse = try await network.request(
                AuthAPI.emailOTP(request: EmailVerifyRequest(email: email, userAction: "VERIFY-EMAIL"))
            )
            state = .otpSent
            ToastManager.shared.show(
                response.message ?? "Code sent to \(email)",
                style: .success,
                position: .bottom
            )
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Verify Email OTP

    func verifyEmailOTP(code: String, onSuccess: @escaping () -> Void) async {
        guard state != .loading else { return }
        state = .loading
        do {
            let _: SuccessResponse = try await network.request(
                AuthAPI.emailVerify(request: EmailOTPRequest(code: code, userAction: "VERIFY-OTP"))
            )
            state = .verified
            onSuccess()
        } catch {
            state = .idle
            alertManager.showError(error.localizedDescription)
        }
    }

    // MARK: - Accept Agreements

    func acceptAgreements() async throws {
        guard state != .loading else { throw ModelError.alreadyLoading }
        state = .loading
        do {
            let _: SuccessResponse = try await network.request(AuthAPI.acceptAgreements)
            state = .idle
        } catch {
            state = .idle
            throw error
        }
    }

    func reset() {
        phoneNumber = ""
        phoneDisplayText = ""
        email = ""
        state = .idle
    }
}

// MARK: - Passkey

extension AuthViewModel {

    /// Returns true if a device passkey has already been registered for the
    /// currently authenticated user. Used by RootView to decide whether the
    /// BiometricEnrollView (which handles passkey registration) must be shown.
    func isPasskeyRegistered() async -> Bool {
        guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
              let json = JWTDecoder.decodePayload(token),
              let payload = json["payload"] as? [String: Any],
              let userIdInt = payload["userId"] as? Int
        else { return false }
        if case .found = keychain.getSync("passkey_registered_\(userIdInt)") { return true }
        return false
    }
}

// MARK: - Biometric Enrollment (per-user)

extension AuthViewModel {

    /// Returns true if the **current user** has completed biometric enrollment on
    /// this device. Stored as a per-user Keychain flag so multiple users sharing
    /// a device each independently track their own enrollment state.
    func isBiometricEnrolledForCurrentUser() async -> Bool {
        guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
              let json = JWTDecoder.decodePayload(token),
              let payload = json["payload"] as? [String: Any],
              let userIdInt = payload["userId"] as? Int
        else { return false }
        if case .found = keychain.getSync("biometric_enrolled_\(userIdInt)") { return true }
        return false
    }

    /// Persists the biometric enrollment flag scoped to the current user.
    /// Called after Face ID verify + Secure Enclave key + RSA registration all succeed.
    func markBiometricEnrolled() async {
        guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
              let json = JWTDecoder.decodePayload(token),
              let payload = json["payload"] as? [String: Any],
              let userIdInt = payload["userId"] as? Int
        else { return }
        try? await keychain.save("1", for: "biometric_enrolled_\(userIdInt)", protection: .backgroundSafe)
        SecureLogger.info("Biometric enrollment marked for user \(userIdInt)", category: .auth)
    }

    /// Removes the biometric enrollment flag for the current user.
    /// Call when the user explicitly revokes Face ID from app settings.
    func clearBiometricEnrollmentForCurrentUser() async {
        guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
              let json = JWTDecoder.decodePayload(token),
              let payload = json["payload"] as? [String: Any],
              let userIdInt = payload["userId"] as? Int
        else { return }
        try? await keychain.delete("biometric_enrolled_\(userIdInt)")
        SecureLogger.info("Biometric enrollment cleared for user \(userIdInt)", category: .auth)
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
            let _: SuccessResponse = try await network.request(
                AuthAPI.enrollRSA(request: RSAEnrollRequest(publicKey: publicKey, deviceId: deviceId, userAction: "RSA_CREATION"))
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

        let deviceId = await DeviceManager.shared.deviceID()

        do {
            // Step 1 — GET /rsa/nonce
            let nonceResponse: RSANonceResponse = try await network.request(
                AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId, userAction: "RSA_NONCE"))
            )
            SecureLogger.info("nonce fetched successfully", category: .auth)

            // Step 2 — sign nonce (evaluatePolicy guarantees Face ID fully completes before signing)
            let signedMessage = try await RSAKeyManager.shared.createSignature(
                payload: nonceResponse.nonce,
                promptMessage: "Sign in with Face ID"
            )

            // Step 3 — POST /auth/token-rsa
            let response: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: signedMessage,
                    deviceId: deviceId,
                    userAction: "RSA_LOGIN"
                ))
            )

            try await keychain.save(response.sessionToken, for: "auth_session_id", protection: .backgroundSafe)

            // Step 4 — exchange session token for access token (silent)
            let tokenResponse: RefreshTokenResponse = try await network.request(AuthAPI.tokenAccess)

            // Step 5 — store access token and mark session active
            try await sessionManager.startSession(accessToken: tokenResponse.accessToken, appState: appState)

            SecureLogger.info("tokenRSA + tokenAccess success — session started", category: .auth)
            lockManager.unlockAfterRSAAuth()
            UserDefaults.standard.set(true, forKey: "kycCompleted")
            // Always verify passkey before routing home — the user may have enrolled
            // biometrics on a previous session without completing passkey registration.
            let passkeyDone = await isPasskeyRegistered()
            appState.flow = passkeyDone ? .home : .enableBiometrics
            return true
        } catch {
            SecureLogger.error("biometric login failed: \(error)", category: .auth)
            ToastManager.shared.show("Biometric login failed. Please use your phone number.", style: .error, position: .bottom)
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
