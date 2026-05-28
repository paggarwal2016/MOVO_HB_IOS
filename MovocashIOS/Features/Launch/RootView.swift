//
//  RootView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var pushManager: PushManager

    @ObservedObject var kycVM: KYCViewModel

    @State private var legalAcceptedItems: Set<String> = []

    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {

            // ── Main flow ──────────────────────────────────────────────────
            NavigationStack {
                ZStack {
                    // Opaque base so flow switches never reveal the UIKit/NavigationStack
                    // default light backing (avoids white glass flashes with blurred layers).
                    Color.movo.background
                        .ignoresSafeArea()

                    switch appState.flow {
                case .splash:
                    SplashScreen()

                case .choice:
                    ChoiceScreen()

                case .loginPhone:
                    PhoneNumberScreen(flowType: .login)

                case .getStartedPhone:
                    PhoneNumberScreen(flowType: .getStarted)

                case .otp:
                    OTPScreen(
                        title: "Enter 6-digit code",
                        subtitle: "We sent a verification code to your mobile \(authVM.phoneNumber.suffix(4))",
                        maxLength: 6,
                        isLoading: authVM.state == .loading,
                        onVerify: { code in
                            await authVM.completeOTPVerification(code: code, appState: appState) { destination in
                                switch destination {
                                case .signupDetails:
                                    appState.flow = .signupDetails
                                default:
                                    // Returning user — KYC already complete.
                                    // Show BiometricEnrollView (which also registers device
                                    // passkey) if not yet done on this device; otherwise go home.
                                    UserDefaults.standard.set(true, forKey: "kycCompleted")
                                    let passkeyDone = await authVM.isPasskeyRegistered()
                                    appState.flow = passkeyDone ? .home : .enableBiometrics
                                }
                            }
                        },
                        onResend: {
                            try await authVM.sendOTP()
                        },
                        onBack: {
                            UIApplication.shared.dismissKeyboard()
                            authVM.reset()
                            appState.flow = appState.context == .login ? .loginPhone : .getStartedPhone
                        }
                    )

                case .signupDetails:
                    SignUpScreen(
                        onBack: { appState.flow = .choice },
                        onContinue: { email in
                            authVM.email = email
                            Task {
                                SpinnerView.showFullScreen()
                                do {
                                    try await authVM.sendEmailOTP()
                                    SpinnerView.hideFullScreen()
                                    AlertManager.shared.showCustom(
                                        title: "Check your email",
                                        message: "We sent a verification link to \(email).",
                                        primary: "Continue",
                                        onPrimary: {
                                            Task {
                                                let passkeyDone = await authVM.isPasskeyRegistered()
                                                appState.flow = passkeyDone ? .getStartedInfo : .enableBiometrics
                                            }
                                        }
                                    )
                                } catch {
                                    SpinnerView.hideFullScreen()
                                    AlertManager.shared.showError(error.localizedDescription)
                                }
                            }
                        },
                        onSignIn: { appState.flow = .loginPhone }
                    )

                case .getStartedInfo:
                    GetStartedInfoScreen(
                        onReady: {
                            Task {
                                do {
                                    try await authVM.acceptAgreements()
                                    appState.flow = .pickDocument
                                } catch {
                                    AlertManager.shared.showError(error.localizedDescription)
                                }
                            }
                        },
                        onNotNow: {
                            Task {
                                await sessionManager.logout(appState: appState)
                                appState.flow = .choice
                                legalAcceptedItems = []
                            }
                        },
                        onBack: {
                            Task {
                                await sessionManager.logout(appState: appState)
                                lockManager.logout()
                                RSAKeyManager.shared.deleteKeyPair()
                                appState.flow = .choice
                                legalAcceptedItems = []
                            }
                        },
                        container: container,
                        isLoading: authVM.state == .loading,
                        acceptedItems: $legalAcceptedItems
                    )

                    // ── Biometric opt-in ──────────────────────────────────────
                case .enableBiometrics:
                    BiometricEnrollView(
                        lockManager: lockManager,
                        onEnable: { return await advanceAfterSecurity() },
                        onSkip:   { Task { await advanceAfterSecurity() } }
                    )

                case .pickDocument:
                    PickDocumentView(
                        onBack: {
                            appState.flow = .getStartedInfo
                        },
                        onContinue: {
                            appState.flow = .kyc
                        }
                    )

                case .appLock:
                    BiometricGateView(
                        biometricIcon: lockManager.biometricType.systemImageName,
                        biometricLabel: lockManager.biometricType.displayName,
                        authenticate: {
                            await authVM.loginWithBiometric(appState: appState)
                        },
                        onAuthenticated: {
                            appState.flow = .home
                        },
                        onUsePhoneNumber: {
                            Task {
                                await sessionManager.logout(appState: appState)
                                lockManager.logout()
                                appState.flow = .choice
                            }
                        }
                    )

                case .warmRelock:
                    BiometricGateView(
                        biometricIcon: lockManager.biometricType.systemImageName,
                        biometricLabel: lockManager.biometricType.displayName,
                        authenticate: {
                            await authVM.loginWithBiometric(appState: appState)
                        },
                        onAuthenticated: {
                            appState.flow = .home
                        },
                        onUsePhoneNumber: {
                            Task {
                                await sessionManager.logout(appState: appState)
                                lockManager.logout()
                                appState.flow = .choice
                            }
                        },
                        autoTriggerBiometric: true
                    )

                case .kyc:
                    EmptyView()

                case .kycSuccess:
                    KYCSuccessView {
                        appState.flow = .home
                    }

                case .home:
                    HomeTabBarView(container: container)
                        .id(appState.protectedShellID)
                }
                }
            }
            .id(appState.protectedShellID)
            // Do not apply implicit animation to `appState.flow` here. Each onboarding
            // screen uses `AmbientGlowView` (heavy blur). Animating flow changes cross-
            // fades those layers against the stack's default background and reads as a
            // white, glass-like flash. Use `withAnimation` only where a transition is
            // intentionally required.
            .environmentObject(authVM)
            .environmentObject(userVM)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)

        }
        .onChangeCompat(of: scenePhase) { newPhase in
            lockManager.handleScenePhase(newPhase)
            // Onboarding inactivity tracking — only active before the dashboard is reached.
            // Post-dashboard users are governed by AppLockManager's background timeout.
            guard !UserDefaults.standard.bool(forKey: "kycCompleted") else { return }
            switch newPhase {
            case .background:
                UserDefaults.standard.set(
                    Date().timeIntervalSince1970,
                    forKey: "onboardingBackgroundedAt"
                )
            case .active:
                let bgAt = UserDefaults.standard.double(forKey: "onboardingBackgroundedAt")
                guard bgAt > 0 else { return }
                let elapsed = Date().timeIntervalSince1970 - bgAt
                UserDefaults.standard.removeObject(forKey: "onboardingBackgroundedAt")
                if elapsed >= AppState.onboardingInactivityTimeout {
                    // Fintech rule: idle > 10 min during onboarding → full logout, start fresh.
                    Task { await sessionManager.logout(appState: appState) }
                }
            default:
                break
            }
        }
        .task(id: appState.flow) {
            guard appState.flow == .kyc else { return }

            // Safety net — if postBootstrap warmup failed (transient network, etc.),
            // retry SDK configuration here before the scanner starts. No-op if
            // configureSDK already succeeded at boot.
            if !container.kycManager.isConfigured {
                do {
                    try await container.kycManager.configureSDK(officeId: AppConfig.officeId)
                } catch {
                    AlertManager.shared.showError(
                        "Failed to initialize KYC: \(error.localizedDescription)"
                    )
                    appState.flow = .pickDocument
                    return
                }
            }

            UserDefaults.standard.set(true, forKey: "kycInProgress")
            await kycVM.startVerification {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                appState.isNewRegistration = true
                appState.flow = .kycSuccess
            } onFailure: {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
                appState.flow = .pickDocument
            }
        }
        .onChangeCompat(of: appState.otpVerified) { verified in
            // Guard: OTPScreen.onVerify is the primary routing handler for the OTP flow.
            // This observer is the fallback for paths that set otpVerified without going
            // through OTPScreen (e.g. deep links). If the flow has already moved away
            // from .otp, OTPScreen.onVerify already handled routing — skip here to
            // avoid double-execution and potential race overrides.
            guard verified, appState.flow == .otp else { return }
            if appState.context == .getStarted {
                // New registration — collect email + phone before security setup
                appState.flow = .signupDetails
            } else {
                // Login flow.
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                Task {
                    if lockManager.isBiometricHardwarePresent {
                        // Check enrollment per-user — not per-device — so User B is never
                        // skipped because User A enrolled on the same device previously.
                        let enrolledForUser = await authVM.isBiometricEnrolledForCurrentUser()
                        if !enrolledForUser {
                            // This user has not enrolled biometrics yet — show the screen.
                            appState.flow = .enableBiometrics
                            return
                        }
                    }
                    // Biometrics either enrolled or no hardware present.
                    // Passkey may still be missing — always verify before routing home.
                    let passkeyDone = await authVM.isPasskeyRegistered()
                    appState.flow = passkeyDone ? .home : .enableBiometrics
                }
            }
        }
        .onChangeCompat(of: appState.flow) { newFlow in
            if UserDefaults.standard.bool(forKey: "kycCompleted") {
                // Post-dashboard — clear any stale onboarding persistence keys.
                UserDefaults.standard.removeObject(forKey: "onboardingLastScreen")
                UserDefaults.standard.removeObject(forKey: "onboardingContext")
                return
            }
            // Mid-onboarding — persist the safe restoration target so that a
            // kill→relaunch within the 10-minute window resumes the correct screen.
            if let target = newFlow.restorationTarget {
                UserDefaults.standard.set(target.rawValue, forKey: "onboardingLastScreen")
                if let ctx = appState.context?.rawValue {
                    UserDefaults.standard.set(ctx, forKey: "onboardingContext")
                }
            }
        }
        .onChangeCompat(of: lockManager.state) { newState in
            // Warm transition: route to .warmRelock so BiometricGateView
            // auto-triggers Face ID. Cold launch uses .appLock (handled by
            // postBootstrap's splash biometric attempt; only reaches .appLock
            // on biometric failure, where manual retry is appropriate).
            guard newState == .locked,
                  lockManager.hasAuthMethod,
                  appState.isAuthenticated,
                  !appState.isNewRegistration,
                  !UserDefaults.standard.bool(forKey: "kycInProgress"),
                  UserDefaults.standard.bool(forKey: "kycCompleted"),
                  appState.flow != .appLock,
                  appState.flow != .warmRelock
            else { return }

            appState.flow = .warmRelock
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { notification in
            guard !sessionManager.isSessionExpired, !sessionManager.isLoggingOut else { return }
            let message = notification.userInfo?["message"] as? String
            Task { @MainActor in
                UIApplication.shared.dismissKeyboard()
                AlertManager.shared.dismiss()
                lockManager.logout()
                authVM.reset()
                userVM.cancelAllTasks()
                await sessionManager.handleSessionExpired(appState: appState, message: message)
            }
        }
    }

    // MARK: -

    /// Called after the user enables or skips biometrics.
    /// Registers the device passkey (mandatory — blocks navigation on failure),
    /// then routes: registration → KYC onboarding  |  login → Home.
    /// Returns true if passkey succeeded and navigation was triggered; false otherwise.
    /// BiometricEnrollView uses the return value to reset its enroll state on failure.
    @discardableResult
    private func advanceAfterSecurity() async -> Bool {
        lockManager.resetToUnlocked()

        // Show a loader immediately so the screen doesn't appear frozen during
        // the JWT decode → SDK configure → passkey UI presentation sequence.
        SpinnerView.showFullScreen()
        await Task.yield()

        let registered = await registerPasskeyIfNeeded()

        // Hide before navigating so the next screen isn't revealed behind the spinner.
        SpinnerView.hideFullScreen()

        guard registered else { return false }   // error already shown — stay on screen

        switch appState.context {
        case .getStarted:
            appState.flow = .getStartedInfo
        default:
            UserDefaults.standard.set(true, forKey: "kycCompleted")
            appState.flow = .home
        }
        return true
    }

    /// Registers the device passkey via MobileBankingSDK (one-time per user/device).
    /// Returns true if already registered or successfully registered now.
    /// Returns false if registration failed — caller must not advance the flow.
    private func registerPasskeyIfNeeded() async -> Bool {
        // Fail-closed: if we cannot decode the token we cannot confirm identity,
        // so block navigation rather than silently proceeding.
        guard let token = try? await container.keychain.get("access_token", biometricPrompt: nil),
              let json = JWTDecoder.decodePayload(token),
              let payload = json["payload"] as? [String: Any],
              let userIdInt = payload["userId"] as? Int
        else {
            SecureLogger.error("Passkey check: unable to decode userId from token — blocking navigation", category: .auth)
            AlertManager.shared.showError("Device registration failed. Please try again.")
            return false
        }

        let userId = String(userIdInt)
        let passkeyKey = "passkey_registered_\(userId)"

        // Keychain is the source of truth (survives OS memory pressure; UserDefaults does not).
        if case .found = container.keychain.getSync(passkeyKey) {
            return true   // already registered on this device
        }

        // Configure MobileBankingSDK with the current token before calling it.
        await PlaidService.shared.configureSDKForTransfer(authToken: token)

        // Wait for any sheet/overlay to finish dismissing before presenting passkey UI.
        var presenter: UIViewController?
        for _ in 0..<20 {
            if let vc = UIApplication.topViewController(),
               vc.presentedViewController == nil || vc.presentedViewController?.isBeingDismissed == true {
                presenter = vc
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let presenter = presenter ?? UIApplication.topViewController() else {
            AlertManager.shared.showError("Device registration failed. Please try again.")
            return false
        }

        let deviceId = await DeviceManager.shared.deviceID()

        do {
            try await PlaidService.shared.registerDevicePasskey(
                userId: userId,
                deviceId: deviceId,
                presentingViewController: presenter
            )
            try? await container.keychain.save("1", for: passkeyKey, protection: .backgroundSafe)
            SecureLogger.info("Device passkey registered for user \(userId)", category: .auth)
            return true
        } catch {
            // Single attempt only — no automatic retry. If the user cancelled the
            // passkey prompt or a network error occurred, surface the error and let
            // them retry manually by tapping the button again.
            SecureLogger.error("Passkey registration failed: \(error.localizedDescription)", category: .auth)
            AlertManager.shared.showError("Device registration failed. Please try again.")
            return false
        }
    }
}
