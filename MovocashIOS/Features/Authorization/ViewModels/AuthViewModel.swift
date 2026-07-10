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
    /// `message` + `description` from the most recent successful Send-OTP. When the
    /// server includes a `description` (e.g. registration "Pre-approved!"),
    /// submitPhoneNumber shows them in a Continue alert before the OTP screen.
    private(set) var lastSendMessage: String?
    private(set) var lastSendDescription: String?
    /// Display-formatted phone carried into WaitlistScreen's phone field when the
    /// user accepts the waitlist gate ("LET'S MOVO"). Cleared on a manual waitlist open.
    var waitlistPrefillPhone: String = ""
    private var isEnrolling = false
    /// In-flight biometric login. Runs as a detached task so neither the hosting
    /// view's `.task` cancellation nor the caller's actor context can abort an
    /// authentication already underway. Concurrent callers join this task instead
    /// of starting a second flow.
    /// Result of a biometric-login attempt, so callers can tell a user-cancel
    /// (retryable, not counted toward the attempt limit) apart from a genuine failure.
    enum BiometricAuthOutcome { case success, cancelled, failed, needsEnrollment }

    private var biometricLoginTask: Task<BiometricAuthOutcome, Never>?
    /// Device-session config fetch started after OTP is sent, so the movo-info key
    /// is ready for the tokenSMS validation step. Awaited in `validateOTP`. This is
    /// the ONLY place `/get/config` is requested — during a fresh login.
    private var deviceConfigTask: Task<Void, Never>?

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

    func sendOTP(showToast: Bool = true) async throws {
        guard state != .loading else { return }
        state = .loading

        do {
            let response: SuccessResponse = try await network.request(
                AuthAPI.messengerOTP(request:
                    MessengerOTPRequest(
                        phoneNumber: phoneNumber,
                        context: context?.rawValue ?? "",
                        userAction: context == .login ? "SEND-LOGIN-OTP" : "SEND-REGISTRATION-OTP",
                        deviceInfo: .current
                    ))
            )
            // The server returns HTTP 200 with `success: false` for the waitlist gate
            // (and similar). That is NOT an OTP send — surface the message so the
            // caller stays on the phone screen and shows it (waitlist alert / error).
            guard response.success != false else {
                throw NetworkError.serverMessage(response.message ?? "Something went wrong")
            }
            lastSendMessage = response.message
            lastSendDescription = response.description
            state = .otpSent
            showOTP = true
            // Fetch the X25519 device-session config now, in the background, so the
            // movo-info key is ready for tokenSMS (OTP validation). This is the only
            // place /get/config is requested — i.e. only on a fresh login.
            deviceConfigTask = Task { [weak self] in try? await self?.configure() }
            if showToast {
                ToastManager.shared.show(
                    response.message ?? "OTP sent successfully",
                    style: .success,
                    position: .bottom
                )
            }
        } catch {
            state = .idle
            throw error
        }
    }

    // MARK: - Validate OTP

    func validateOTP(code: String) async throws -> AuthTokenSMSResponse {
        guard state != .loading else { throw ModelError.alreadyLoading }
        state = .loading

        // tokenSMS requires the movo-info header. Wait for the config fetch started
        // after sendOTP; if it didn't populate, fetch once more before validating.
        await deviceConfigTask?.value
        if await !DeviceSessionManager.shared.hasConfig() {
            try? await configure()
        }

        do {
            let response: AuthTokenSMSResponse = try await network.request(
                AuthAPI.tokenSMS(request: TokenSMSRequest(
                    phoneNumber: phoneNumber,
                    code: code,
                    userAction: context == .login ? "VERIFY-LOGIN-OTP" : "VERIFY-REGISTRATION-OTP"
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

            // Best-effort App Attest registration; fail-open, never blocks or breaks login.
            Task.detached { await AppAttestRegistrationService.shared.registerIfNeeded() }

            analytics.trackLogin(method: .otp)
            let destination: AuthFlow = context == .login ? .home : .signupDetails
            reset()
            await onNavigate(destination)
        } catch is CancellationError {
            // Benign — the request was cancelled (e.g. the user navigated away).
            // Nothing to surface. Pinning failures now throw `.secureConnectionFailed`.
            return
        } catch {
            analytics.trackLoginFailed(method: .otp, errorCode: error.localizedDescription)
            alertManager.showError(error.localizedDescription)
        }
    }

    // MARK: - Phone Input Formatting

    private var phonePreviousText: String = ""

    func handlePhoneInput(_ newValue: String) {
        let isDeleting = newValue.count < phonePreviousText.count

        // Strip non-numeric characters.
        var digits = newValue.filter { $0.isNumber }

        // Normalize an 11-digit paste with US country code before the 10-digit mask runs.
        if digits.count == 11 && digits.hasPrefix("1") {
            digits = String(digits.dropFirst())
        }

        // Cap to 10 digits (same behaviour as PhoneFormatter.raw).
        digits = String(digits.prefix(10))

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
        // Normalize to E.164. The view pre-validates and shows inline errors, so a
        // failure here means the call was made without going through the normal UI
        // path — return silently rather than showing a duplicate error.
        guard case .success(let e164) = PhoneNormalizer.normalizePhone(phoneNumber) else { return }
        phoneNumber = e164
        context = appState.context

        if context == .getStarted {
            analytics.log(AnalyticsEvent.signupStarted)
        }

        do {
            // Suppress the toast here — when the server returns a `description`
            // (registration "Pre-approved!"), we surface it in a Continue alert
            // instead; otherwise we show the toast ourselves below.
            try await sendOTP(showToast: false)
            if context == .getStarted {
                analytics.log(AnalyticsEvent.signupPhoneSubmitted)
            }
            if let description = lastSendDescription, !description.isEmpty {
                AlertManager.shared.showCustom(
                    title: lastSendMessage ?? "Pre-approved!",
                    message: description,
                    primary: "Continue",
                    primaryIcon: "arrow.right",
                    icon: .success,
                    onPrimary: { appState.flow = .otp }
                )
            } else {
                // No description (e.g. login) — keep the original toast + direct navigation.
                ToastManager.shared.show(
                    lastSendMessage ?? "OTP sent successfully",
                    style: .success,
                    position: .bottom
                )
                appState.flow = .otp
            }
        } catch is CancellationError {
            // Benign — the request was cancelled (e.g. the user navigated away).
            // Nothing to surface. Pinning failures now throw `.secureConnectionFailed`.
            return
        } catch {
            if let message = waitlistMessage(from: error) {
                AlertManager.shared.showCustom(
                    title: "Join the waitlist",
                    message: message,
                    primary: "LET'S MOVO!",
                    secondary: "SKIP",
                    icon: .movo,
                    onPrimary: {
                        // Carry the entered phone into the waitlist form's phone field.
                        self.waitlistPrefillPhone = self.phoneDisplayText.isEmpty
                            ? String(self.phoneNumber.filter(\.isNumber).suffix(10))
                            : self.phoneDisplayText
                        appState.flow = .waitlist
                    },
                    onSecondary: { appState.flow = .choice }
                )
            } else {
                alertManager.showError(error.localizedDescription)
            }
        }
    }

    /// Returns the server message when an error is the backend's "join the waitlist"
    /// gate (a `serverMessage` whose text mentions the wait list), else `nil`.
    private func waitlistMessage(from error: Error) -> String? {
        guard let net = error as? NetworkError, case .serverMessage(let msg) = net else { return nil }
        let normalized = msg.lowercased().replacingOccurrences(of: " ", with: "")
        return normalized.contains("waitlist") ? msg : nil
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
            let response: UserProfileAPIResponse = try await network.request(UserAPI.verifyEmailStatus)
            if response.data.emailVerified {
                analytics.log(AnalyticsEvent.signupEmailVerified)
                return .verified
            }
            return .notVerified
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
            analytics.log(AnalyticsEvent.signupTermsAccepted)
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
                    userAction: "RSA-CREATION"
                ))
            )
            SecureLogger.info("RSA key enrolled successfully", category: .auth)
        } catch {
            RSAKeyManager.shared.deleteKeyPair()   // keep local/server in sync on failure
            SecureLogger.error("RSA enrollment failed: \(error.localizedDescription)", category: .auth)
            throw error
        }
    }

    // ── Login: GET /rsa/nonce → sign → POST /auth/token-rsa ──────────────────
    // Returns true on success. Caller unlocks the app silently after success.
    @discardableResult
    func loginWithBiometric(appState: AppState, navigateOnSuccess: Bool = true) async -> Bool {
        await runBiometricLogin(appState: appState, navigateOnSuccess: navigateOnSuccess) == .success
    }

    /// Same as `loginWithBiometric` but returns the full outcome so callers can
    /// distinguish a user-cancel (retryable) from a genuine failure — used by the
    /// post-OTP login biometric gate to enforce a 3-attempt limit.
    func loginWithBiometricOutcome(appState: AppState) async -> BiometricAuthOutcome {
        await runBiometricLogin(appState: appState, navigateOnSuccess: false)
    }

    private func runBiometricLogin(appState: AppState, navigateOnSuccess: Bool) async -> BiometricAuthOutcome {
        // Join an attempt that's already running rather than starting a second flow
        // (which would trigger a duplicate nonce request / Face ID prompt).
        if let existing = biometricLoginTask {
            return await existing.value
        }

        analytics.trackLoginAttempt(method: .biometric)

        // Run the flow in a detached task: it does NOT inherit cancellation from the
        // caller's task, so if the hosting view's `.task` is cancelled by a re-render
        // the login still completes instead of throwing CancellationError mid-flight.
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> BiometricAuthOutcome in
            guard let self else { return .failed }
            return await self.performBiometricLogin(appState: appState, navigateOnSuccess: navigateOnSuccess)
        }
        biometricLoginTask = task
        defer { biometricLoginTask = nil }
        return await task.value
    }

    func cancelBiometricLogin() {
        biometricLoginTask?.cancel()
        biometricLoginTask = nil
    }

    private func performBiometricLogin(appState: AppState, navigateOnSuccess: Bool) async -> BiometricAuthOutcome {

        let deviceId = await DeviceManager.shared.deviceID()

        do {
            // Step 1 — GET /rsa/nonce
            let nonceResponse: RSANonceResponse = try await network.request(
                AuthAPI.nonceRSA(request: RSANonceRequest(deviceId: deviceId, userAction: "RSA-NONCE"))
            )
            SecureLogger.info("nonce fetched successfully", category: .auth)

            // After the nonce, refresh the device-session config in the background so
            // token-rsa uses a fresh movo-info key. Awaited before Step 3. This is the
            // biometric-login equivalent of the post-OTP config fetch.
            let configTask = Task { [weak self] in try? await self?.configure() }

            // Step 2 — sign nonce (evaluatePolicy guarantees Face ID fully completes before signing)
            let signedMessage = try await RSAKeyManager.shared.createSignature(
                payload: nonceResponse.nonce,
                promptMessage: "Sign in with Face ID"
            )

            // Ensure the refreshed config is ready before token-rsa (needs movo-info).
            await configTask.value

            // Step 3 — POST /auth/token-rsa
            let response: RSATokenResponse = try await network.request(
                AuthAPI.tokenRSA(request: RSATokenRequest(
                    signedMessage: signedMessage,
                    deviceId: deviceId,
                    userAction: "RSA-LOGIN"
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
                analytics.trackLogin(method: .biometric)
                lockManager.unlockAfterRSAAuth()
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                if navigateOnSuccess {
                    appState.flow = passkeyDone ? .home : .enableBiometrics
                }
            }

            return .success

        } catch is CancellationError {
            SecureLogger.info("Biometric login cancelled — discarding attempt", category: .auth)
            return .cancelled
        } catch let biometricError as BiometricLoginError {
            SecureLogger.error("biometric login failed: \(biometricError)", category: .auth)
            switch biometricError {
            case .userCanceled:
                // User dismissed the prompt — not counted as a failed attempt.
                analytics.trackLoginFailed(method: .biometric, errorCode: "user_cancelled")
                return .cancelled
            case .keyNotFound:
                // The local RSA key is gone (e.g. a reinstall wiped it, or the
                // enrollment state is stale). Biometric auth can never succeed here —
                // signal the caller to re-enroll rather than counting a scan failure.
                analytics.trackLoginFailed(method: .biometric, errorCode: "rsa_key_missing")
                return .needsEnrollment
            case .lockout:
                // Biometry is locked at the OS level. Repeated "Try Again" taps cannot
                // succeed until the device is unlocked with the passcode, so tell the
                // user exactly that instead of the generic failure message.
                analytics.trackLoginFailed(method: .biometric, errorCode: "biometric_lockout")
                ToastManager.shared.show(biometricError.localizedDescription, style: .error, position: .bottom)
                return .failed
            default:
                analytics.trackLoginFailed(method: .biometric, errorCode: "\(biometricError)")
                ToastManager.shared.show("Biometric login failed. Please use your phone number.", style: .error, position: .bottom)
                return .failed
            }
        } catch {
            analytics.trackLoginFailed(method: .biometric, errorCode: error.localizedDescription)
            SecureLogger.error("biometric login failed: \(error)", category: .auth)
            ToastManager.shared.show("Biometric login failed. Please use your phone number.", style: .error, position: .bottom)
            return .failed
        }
    }
}

extension AuthViewModel {

    /// Submits a waitlist entry to `POST /waitlist/join`. Throws on network/decode
    /// failure so the caller can surface the error.
    /// - Returns: the server's success message, if any, for the caller to display.
    @discardableResult
    func joinTheWaitList(firstName: String, lastName: String, email: String, phoneNumber: String) async throws -> String? {
        let response: SuccessResponse = try await network.request(
            AuthAPI.waitList(request: WaitListRequest(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                deviceInfo: .current,
                userAction: "WAIT-LIST-JOIN"
            ))
        )
        return response.message
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
