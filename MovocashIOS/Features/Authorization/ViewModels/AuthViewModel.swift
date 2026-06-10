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
    /// In-flight biometric login. Runs as a detached task so neither the hosting
    /// view's `.task` cancellation nor the caller's actor context can abort an
    /// authentication already underway. Concurrent callers join this task instead
    /// of starting a second flow.
    private var biometricLoginTask: Task<Bool, Never>?

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
                    MessengerOTPRequest(
                        phoneNumber: phoneNumber,
                        context: context?.rawValue ?? "",
                        userAction: "SEND_OTP",
                        deviceInfo: .current
                    ))
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
            let _: SuccessResponse = try await network.request(
                AuthAPI.emailVerify(request: EmailVerifyRequest(email: email, userAction: "VERIFY-EMAIL"))
            )
            state = .otpSent
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
                AuthAPI.emailVerify(request: EmailVerifyRequest(email: email, userAction: "VERIFY-EMAIL"))
            )
            state = .verified
            onSuccess()
        } catch {
            state = .idle
            alertManager.showError(error.localizedDescription)
        }
    }

    // MARK: - Email Verification Status

    /// Fetches the latest profile and reports the email verification status.
    /// The backend marks the email verified once the user opens the secure link
    /// sent by `sendEmailOTP()`. Used by the email-verification waiting screen to
    /// gate progression into the rest of registration / KYC.
    ///
    /// Distinguishes a confirmed "not verified yet" (`.notVerified`) from an
    /// inability to reach the server (`.failed`) so the UI never tells the user
    /// their email is unverified when the real problem was connectivity. Either
    /// non-verified outcome keeps the user on the verification step.
    func checkEmailVerified() async -> EmailVerificationCheck {
        do {
            let response: UserProfileAPIResponse = try await network.request(UserAPI.getProfile)
            return response.data.emailVerified ? .verified : .notVerified
        } catch {
            return .failed
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

    // MARK: - Configure

    /// Fetches the X25519 device-session config from `/v1/device/config` and persists
    /// the server public key + sessionId to the Keychain. These back the `movo-info`
    /// header (X25519 → HKDF-SHA256 → AES-256-GCM) built by `DeviceSessionManager`.
    func configure() async throws {
        let info: ConfigureResponse = try await network.request(AuthAPI.deviceConfig)
        try await KeychainManager.shared.save(info.movoSessionConfig, for: DeviceSessionManager.publicKeyKey, protection: .backgroundSafe)
        try await KeychainManager.shared.save(info.sessionId, for: DeviceSessionManager.sessionIdKey, protection: .backgroundSafe)
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
    func enrollRSA() async throws {
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
                AuthAPI.enrollRSA(request: RSAEnrollRequest(
                    publicKey: publicKey,
                    deviceId: deviceId,
                    userAction: "RSA_CREATION"
                ))
            )
            SecureLogger.info("RSA key enrolled successfully", category: .auth)
        } catch {
            RSAKeyManager.shared.deleteKeyPair()   // keep local/server in sync on failure
            SecureLogger.error("RSA enrollment failed: \(error.localizedDescription)", category: .auth)
            // Surface the real failure to the caller instead of swallowing it, so the
            // UI can show the actual error and never mark biometrics enabled on failure.
            throw error
        }
    }

    // ── Login: GET /rsa/nonce → sign → POST /auth/token-rsa ──────────────────
    // Returns true on success. Caller unlocks the app silently after success.
    @discardableResult
    func loginWithBiometric(appState: AppState) async -> Bool {
        // Join an attempt that's already running rather than starting a second flow
        // (which would trigger a duplicate nonce request / Face ID prompt).
        if let existing = biometricLoginTask {
            return await existing.value
        }

        // Run the flow in a detached task: it does NOT inherit cancellation from the
        // caller's task, so if the hosting view's `.task` is cancelled by a re-render
        // the login still completes instead of throwing CancellationError mid-flight.
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> Bool in
            guard let self else { return false }
            return await self.performBiometricLogin(appState: appState)
        }
        biometricLoginTask = task
        defer { biometricLoginTask = nil }
        return await task.value
    }

    @discardableResult
    private func performBiometricLogin(appState: AppState) async -> Bool {

        let deviceId = await DeviceManager.shared.deviceID()

        // ── TEMP DIAGNOSTIC — remove once token-rsa 400 is resolved ──────────
        // deviceId must be byte-identical at enroll, nonce and token-rsa.
        // keysExist == false here means no private key is on this device, so the
        // server can have no matching public key (enrollment never succeeded).
        SecureLogger.info(
            "RSA login diag — deviceId=\(deviceId), keysExist=\(RSAKeyManager.shared.keysExist())",
            category: .auth
        )
        // ─────────────────────────────────────────────────────────────────────

        do {
            // Step 1 — GET /rsa/nonce
            let nonceResponse: RSANonceResponse = try await network.request(
                AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId, userAction: "RSA_NONCE"))
            )
            SecureLogger.info("nonce fetched successfully", category: .auth)

            // ── TEMP DIAGNOSTIC — remove once token-rsa 400 is resolved ──────
            // Capture the exact nonce so we can confirm with the backend which
            // bytes the signature must cover (raw string vs base64-decoded blob).
            SecureLogger.info(
                "RSA nonce diag — value=\(nonceResponse.nonce), length=\(nonceResponse.nonce.count)",
                category: .auth
            )
            // ─────────────────────────────────────────────────────────────────

            // Step 2 — sign nonce (evaluatePolicy guarantees Face ID fully completes before signing)
            let signedMessage = try await RSAKeyManager.shared.createSignature(
                payload: nonceResponse.nonce,
                promptMessage: "Sign in with Face ID"
            )

            // ── TEMP DIAGNOSTIC — remove once token-rsa 400 is resolved ──────
            SecureLogger.info("RSA signedMessage diag — length=\(signedMessage.count)", category: .auth)
            // ─────────────────────────────────────────────────────────────────

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

            // Step 6 — check passkey status before navigating
            // Done before the MainActor hop so we don't hold the main thread during the
            // Keychain read.
            let passkeyDone = await isPasskeyRegistered()

            // Step 7 — all UI mutations and navigation on MainActor.
            // appState is an @MainActor-bound ObservableObject; mutating it from a
            // detached task without this hop is a data race.
            await MainActor.run {
                lockManager.unlockAfterRSAAuth()
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                appState.flow = passkeyDone ? .home : .enableBiometrics
            }

            return true

        } catch is CancellationError {
            // With Task.detached this should never fire. If you see this log, something
            // inside the flow is explicitly cancelling the task — investigate immediately.
            SecureLogger.warning("⚠️ Unexpected CancellationError in detached biometric task — investigate", category: .auth)
            return false
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

/// Result of an email-verification status check.
/// `notVerified` = server reached, email confirmed not-yet-verified.
/// `failed` = could not reach the server / decode the response.
enum EmailVerificationCheck: Equatable {
    case verified
    case notVerified
    case failed
}
