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
    @EnvironmentObject private var idleTimer: IdleTimerManager

    @ObservedObject var kycVM: KYCViewModel

    @State private var legalAcceptedItems: Set<String> = []

    /// Client-side jailbreak/integrity gate. When true, CompromisedDeviceView
    /// covers the whole app and blocks all interaction. Seeded from a synchronous,
    /// cache-free snapshot so the block wins the very first frame (no pre-render
    /// flash of the real UI on a compromised device); the launch check, the
    /// foreground re-check, and the network layer's `.deviceCompromised` broadcast
    /// then re-confirm and catch instrumentation attached after launch.
    /// Bypassable on a rooted device — defense in depth, not a guarantee.
    @State private var deviceCompromised = JailbreakDetector.shared.isCompromisedSnapshot()

    /// Ensures the compromise telemetry event is emitted exactly once per session,
    /// regardless of whether the flag was raised at frame 1, on foreground, or by
    /// the network layer.
    @State private var compromiseReported = false

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
                        .trackScreen(AnalyticsScreen.choice)

                case .waitlist:
                    WaitlistScreen(
                        initialPhone: authVM.waitlistPrefillPhone,
                        onBack: {
                            UIApplication.shared.dismissKeyboard()
                            appState.flow = .choice
                        },
                        onSubmitted: {
                            // The success alert is shown by WaitlistScreen; this just
                            // returns to Choice once the user acknowledges it.
                            appState.flow = .choice
                        }
                    )
                    .trackScreen(AnalyticsScreen.waitlist)

                case .loginPhone:
                    PhoneNumberScreen(flowType: .login)
                        .trackScreen(AnalyticsScreen.phoneLogin)

                case .getStartedPhone:
                    PhoneNumberScreen(flowType: .getStarted)
                        .trackScreen(AnalyticsScreen.phoneSignup)

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
                                    legalAcceptedItems = []
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
                    .trackScreen(AnalyticsScreen.otp)

                case .signupDetails:
                    SignUpScreen(
                        onBack: { appState.flow = .choice },
                        onContinue: { email in
                            authVM.email = email
                            container.analytics.log(AnalyticsEvent.signupEmailSubmitted)
                            Task {
                                SpinnerView.showFullScreen()
                                // Check the profile's email-verified status first.
                                //  • already verified → skip verification, go straight to
                                //    the next onboarding step (biometric / passcode).
                                //  • not verified    → send the verification email and
                                //    show the verification waiting screen.
                                switch await authVM.checkEmailVerified() {
                                case .verified:
                                    // Email verified → collect the account password
                                    // before continuing the existing flow.
                                    SpinnerView.hideFullScreen()
                                    appState.flow = .setPassword
                                case .notVerified:
                                    do {
                                        try await authVM.sendEmailOTP()
                                        SpinnerView.hideFullScreen()
                                        appState.flow = .emailVerification
                                    } catch {
                                        SpinnerView.hideFullScreen()
                                        AlertManager.shared.showError(error.localizedDescription)
                                    }
                                case .failed:
                                    SpinnerView.hideFullScreen()
                                    ToastManager.shared.show(
                                        "Couldn't check your verification status. Please try again.",
                                        style: .error,
                                        position: .bottom
                                    )
                                }
                            }
                        },
                        onSignIn: { appState.flow = .loginPhone }
                    )
                    .trackScreen(AnalyticsScreen.emailEntry)

                case .emailVerification:
                    EmailVerificationView(
                        email: authVM.email,
                        onCheck: { isExplicit in
                            // Full-screen loader for explicit taps only; the silent
                            // foreground re-check stays invisible so returning to the
                            // app after opening the link feels seamless.
                            if isExplicit { SpinnerView.showFullScreen() }
                            let result = await authVM.checkEmailVerified()
                            switch result {
                            case .verified:
                                // Email verified → collect the account password
                                // before continuing the existing flow.
                                if isExplicit { SpinnerView.hideFullScreen() }
                                appState.flow = .setPassword
                            case .notVerified:
                                if isExplicit {
                                    SpinnerView.hideFullScreen()
                                    showEmailNotVerifiedToast()
                                }
                            case .failed:
                                if isExplicit {
                                    SpinnerView.hideFullScreen()
                                    ToastManager.shared.show(
                                        "Couldn't check your verification status. Please try again.",
                                        style: .error,
                                        position: .bottom
                                    )
                                }
                            }
                        },
                        onResend: {
                            SpinnerView.showFullScreen()
                            do {
                                try await authVM.sendEmailOTP()
                                SpinnerView.hideFullScreen()
                                ToastManager.shared.show(
                                    "Verification email sent to \(authVM.email)",
                                    style: .success,
                                    position: .bottom
                                )
                            } catch {
                                SpinnerView.hideFullScreen()
                                ToastManager.shared.show(
                                    error.localizedDescription,
                                    style: .error,
                                    position: .bottom
                                )
                            }
                        },
                        onBack: { appState.flow = .signupDetails }
                    )
                    .trackScreen(AnalyticsScreen.emailVerification)

                case .setPassword:
                    SetPasswordScreen(onSubmit: { password in
                        do {
                            try await authVM.setInitialPassword(password)
                            let passkeyDone = await authVM.isPasskeyRegistered()
                            appState.flow = passkeyDone ? .getStartedInfo : .enableBiometrics
                            return true
                        } catch {
                            ToastManager.shared.show(
                                error.localizedDescription,
                                style: .error,
                                position: .bottom
                            )
                            return false
                        }
                    }, onBack: {
                        appState.flow = .emailVerification
                    })
                    .trackScreen(AnalyticsScreen.setPassword)

                case .getStartedInfo:
                    GetStartedInfoScreen(
                        onReady: {
                            Task {
                                do {
                                    try await authVM.acceptAgreements()
                                    // Normal forward entry — Get Started Info is behind
                                    // Pick Document, so Back returns there (not a resume).
                                    appState.kycStepResumed = false
                                    appState.flow = .pickDocument
                                } catch {
                                    AlertManager.shared.showError(error.localizedDescription)
                                }
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
                        acceptedItems: $legalAcceptedItems
                    )
                    .trackScreen(AnalyticsScreen.terms)

                    // ── Biometric opt-in ──────────────────────────────────────
                case .enableBiometrics:
                    BiometricEnrollView(
                        lockManager: lockManager,
                        onEnable: { return await advanceAfterSecurity() },
                        onSkip:   { Task { await advanceAfterSecurity() } },
                        onOpenSettings: {
                            // User is leaving for Settings to enable a denied/disabled
                            // biometric. iOS force-relaunches the app (cold launch) once
                            // the permission changes; this flag lets StartupRouter resume
                            // here instead of starting over at Choice.
                            UserDefaults.standard.set(true, forKey: "onboardingBiometricAwaitingSettings")
                        }
                    )

                case .pickDocument:
                    PickDocumentView(
                        onBack: {
                            if appState.kycStepResumed {
                                // Resumed straight into KYC after a camera-permission
                                // grant relaunch — no Get Started Info behind this screen,
                                // so Back exits to Choice. Clear the resume markers so a
                                // later manual kill won't re-resume here.
                                appState.kycStepResumed = false
                                UserDefaults.standard.removeObject(forKey: "onboardingKycStep")
                                UserDefaults.standard.removeObject(forKey: "onboardingKycCameraAuth")
                                appState.flow = .choice
                            } else {
                                appState.flow = .getStartedInfo
                            }
                        },
                        onContinue: {
                            appState.flow = .kyc
                        }
                    )
                    .trackScreen(AnalyticsScreen.kycDocument)

                case .appLock:
                    BiometricGateView(
                        biometricIcon: lockManager.biometricType.systemImageName,
                        biometricLabel: lockManager.biometricType.displayName,
                        authenticate: {
                            await authVM.loginWithBiometric(appState: appState, navigateOnSuccess: false)
                        },
                        onAuthenticated: {
                            appState.flow = .home
                        },
                        onUsePhoneNumber: {
                            // Cancel any in-flight (e.g. timed-out splash) biometric
                            // attempt first, so a late success can't resurrect the
                            // session the user is about to discard.
                            authVM.cancelBiometricLogin()
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
                            await authVM.loginWithBiometric(appState: appState, navigateOnSuccess: false)
                        },
                        onAuthenticated: {
                            appState.flow = .home
                        },
                        onUsePhoneNumber: {
                            // Cancel any in-flight biometric attempt first, so a late
                            // success can't resurrect the session the user is about to
                            // discard.
                            authVM.cancelBiometricLogin()
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
                    KYCSuccessView(
                        container: container,
                        onFinish: {
                            container.analytics.log(AnalyticsEvent.signupCompleted)
                            UserDefaults.standard.set(true, forKey: "hasCompletedSignup")
                            appState.flow = .home
                        },
                        onSkip: {
                            container.analytics.log(AnalyticsEvent.signupCompleted)
                            UserDefaults.standard.set(true, forKey: "hasCompletedSignup")
                            appState.flow = .home
                        }
                    )
                    .trackScreen(AnalyticsScreen.kycSuccess)

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

            // ── Compromised-device gate ────────────────────────────────────
            // Renders above the entire flow and blocks all interaction with it.
            // Also enforced at the network layer (NetworkError.jailbreakDetected).
            if deviceCompromised {
                Color.movo.background
                    .ignoresSafeArea()
                CompromisedDeviceView(onRetry: {
                    // Re-evaluate. A device cannot un-jailbreak within a session, so a
                    // confirmed positive stays flagged (the detector caches it). The
                    // gate only clears if a relaunch cleared the cache. No programmatic
                    // exit — the block simply stays up (Apple HIG: never quit an app).
                    let stillCompromised = await JailbreakDetector.shared.recheck()
                    deviceCompromised = stillCompromised
                    return stillCompromised
                })
            }
        }
        // Reset the idle clock on any touch anywhere in the app.
        // `simultaneousGesture` observes without consuming — existing gestures are unaffected.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in idleTimer.recordActivity() }
        )
        // Start the idle timer when the home dashboard is visible; stop it otherwise.
        .onChangeCompat(of: appState.flow) { newFlow in
            if newFlow == .home {
                idleTimer.start()
            } else {
                idleTimer.stop()
            }
        }
        .onChangeCompat(of: scenePhase) { newPhase in
            lockManager.handleScenePhase(newPhase)
            // Re-check integrity on foreground: instrumentation (Frida, a debugger)
            // can be attached after launch, so re-evaluate every time the app returns
            // to active. A positive result stays flagged for the session.
            if newPhase == .active {
                idleTimer.recordActivity()
                Task {
                    if await JailbreakDetector.shared.isJailbroken { deviceCompromised = true }
                    reportCompromiseIfNeeded(trigger: "foreground")
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            // Onboarding flows live on a non-home branch; swap the root to home so
            // the whole onboarding stack tears down in one transition.
            if appState.flow != .home {
                appState.flow = .home
            }
        }
        .task(id: appState.flow) {
            guard appState.flow == .kyc else { return }

            // Safety net — if postBootstrap warmup failed (transient network, etc.),
            // retry SDK configuration here before the scanner starts. No-op if
            // configureSDK already succeeded at boot.
            do {
                try await container.kycManager.configureSDK(officeId: AppConfig.officeId)
            } catch {
                AlertManager.shared.showError(
                    "Failed to initialize KYC: \(error.localizedDescription)"
                )
                appState.flow = .pickDocument
                return
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

            // Clear any transient alert so it can't sit above the biometric gate.
            AlertManager.shared.dismiss()
            appState.flow = .warmRelock
        }
        .task {
            // Proactive integrity check at launch — shows the gate before any
            // flow renders on a compromised device (no network call required).
            // The synchronous snapshot may already have flagged it at frame 1;
            // this confirms via the authoritative caching path.
            if await JailbreakDetector.shared.isJailbroken { deviceCompromised = true }
            reportCompromiseIfNeeded(trigger: "launch")
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceCompromised)) { _ in
            // Raised by the network layer (NetworkService) when it rejects a call
            // on a flagged device — see DeviceIntegrityNotifier.
            deviceCompromised = true
            reportCompromiseIfNeeded(trigger: "network")
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

    // MARK: - Device Integrity

    /// Reports the compromise telemetry event exactly once per session so the
    /// backend/fraud team has visibility into flagged devices. Fires only on the
    /// first detection, never on repeated foreground/network re-checks. No PII or
    /// path details are logged — only that a jailbreak was detected and what
    /// triggered the check.
    @MainActor
    private func reportCompromiseIfNeeded(trigger: String) {
        guard deviceCompromised, !compromiseReported else { return }
        compromiseReported = true
        container.analytics.log(AnalyticsEvent.suspiciousActivity, params: [
            AnalyticsParam.reason: "jailbreak_detected",
            AnalyticsParam.type: trigger
        ])
    }

    // MARK: -

    /// Called after the user enables or skips biometrics.
    /// Registers the device passkey (mandatory — blocks navigation on failure),
    /// then routes: registration → KYC onboarding  |  login → Home.
    /// Returns true if passkey succeeded and navigation was triggered; false otherwise.
    /// BiometricEnrollView uses the return value to reset its enroll state on failure.
    /// Shown when the explicit "Continue" check finds the email still unverified
    /// (link not yet opened, or token expired). Offers to resend the link.
    private func showEmailNotVerifiedToast() {
        ToastManager.shared.show(ToastConfig(
            message: "We haven't received your confirmation yet. Open the link we emailed you, or resend it.",
            style: .warning,
            position: .center,
            duration: nil,
            title: "Email not verified",
            imageSystemName: "envelope.badge",
            primaryAction: ToastAction(label: "Resend email") {
                Task {
                    do {
                        try await authVM.sendEmailOTP()
                        ToastManager.shared.show(
                            "Verification email sent to \(authVM.email)",
                            style: .success,
                            position: .bottom
                        )
                    } catch {
                        ToastManager.shared.show(
                            error.localizedDescription,
                            style: .error,
                            position: .bottom
                        )
                    }
                }
            },
            secondaryAction: ToastAction(label: "Dismiss") { },
            dimsBackground: true
        ))
    }

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
            UserDefaults.standard.set(true, forKey: "hasCompletedSignup")
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
