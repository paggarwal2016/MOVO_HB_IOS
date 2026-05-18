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
    @State private var isAttemptingSilentBiometric: Bool = false

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
                                    UserDefaults.standard.set(true, forKey: "kycCompleted")
                                    if lockManager.isBiometricHardwarePresent && !RSAKeyManager.shared.keysExist() {
                                        appState.flow = .enableBiometrics
                                    } else {
                                        appState.flow = .home
                                    }
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
                                do {
                                    try await authVM.sendEmailOTP()
                                    appState.flow = .emailOTP
                                } catch {
                                    AlertManager.shared.showError(error.localizedDescription)
                                }
                            }
                        },
                        onSignIn: { appState.flow = .loginPhone }
                    )

                case .emailOTP:
                    OTPScreen(
                        title: "Verify email",
                        subtitle: "A 6-digit verification code was sent to \(authVM.email)",
                        maxLength: 6,
                        isLoading: authVM.state == .loading,
                        onVerify: { code in
                            await authVM.verifyEmailOTP(code: code) {
                                if lockManager.isBiometricHardwarePresent
                                    && !lockManager.isBiometricEnabled
                                    && !RSAKeyManager.shared.keysExist() {
                                    appState.flow = .enableBiometrics
                                } else {
                                    appState.flow = .getStartedInfo
                                }
                            }
                        },
                        onResend: {
                            try await authVM.sendEmailOTP()
                        },
                        onBack: { appState.flow = .signupDetails }
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
                        onEnable: { advanceAfterSecurity() },  // enabled  → home or kyc
                        onSkip:   { advanceAfterSecurity() }   // skipped  → home or kyc
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

            // ── Warm-transition lock overlay ───────────────────────────────
            if shouldShowLockOverlay {
                BiometricGateView(
                    biometricIcon: lockManager.biometricType.systemImageName,
                    biometricLabel: lockManager.biometricType.displayName,
                    authenticate: {
                        await authVM.loginWithBiometric(appState: appState)
                    },
                    onAuthenticated: {
                        // No-op: loginWithBiometric calls unlockAfterRSAAuth()
                        // (state → .unlocked → shouldShowLockOverlay false →
                        // overlay dismisses) and sets appState.flow = .home
                        // (already .home on warm transition).
                    },
                    onUsePhoneNumber: {
                        Task {
                            await sessionManager.logout(appState: appState)
                            lockManager.logout()
                            appState.flow = .choice
                        }
                    },
                    autoTriggerBiometric: false
                )
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowLockOverlay)
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
            guard verified else { return }
            if appState.context == .getStarted {
                // New registration — collect email + phone before security setup
                appState.flow = .signupDetails
            } else {
                // Login flow — skip passcode, enroll biometric if available
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                if lockManager.isBiometricHardwarePresent && !RSAKeyManager.shared.keysExist() {
                    appState.flow = .enableBiometrics
                } else {
                    appState.flow = .home
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
            // When lock state transitions to .locked for a biometric-enrolled
            // user, attempt biometric silently. The Face ID system dialog
            // appears over the underlying screen — no Movo-branded overlay
            // unless this attempt fails. Matches cold-launch postBootstrap
            // pattern (silent attempt → only show retry UI on failure).
            guard newState == .locked,
                  lockManager.hasAuthMethod,
                  appState.flow != .appLock,    // cold-launch handled by postBootstrap
                  !isAttemptingSilentBiometric
            else { return }

            isAttemptingSilentBiometric = true
            Task {
                let success = await authVM.loginWithBiometric(appState: appState)
                isAttemptingSilentBiometric = false
                if !success {
                    // Mark retry needed → overlay will appear via shouldShowLockOverlay
                    lockManager.biometricRetryRequired = true
                }
                // On success, loginWithBiometric → unlockAfterRSAAuth →
                // state = .unlocked → no overlay ever shown.
            }
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

    private var shouldShowLockOverlay: Bool {
        lockManager.state == .locked
            && lockManager.biometricRetryRequired
            && lockManager.hasAuthMethod
            && appState.isAuthenticated
            && !appState.isNewRegistration
            && !UserDefaults.standard.bool(forKey: "kycInProgress")
            && UserDefaults.standard.bool(forKey: "kycCompleted")
            && appState.flow != .appLock   // avoid double-render on cold-launch
    }

    /// After biometric step:
    /// registration → KYC  |  login (KYC already done) → Home
    private func advanceAfterSecurity() {
        // User just completed passcode/biometric setup. If they backgrounded the app
        // during setup (e.g. went to Settings to enable Face ID), handleScenePhase
        // may have set state = .locked. Clear it now — identity was proven during
        // setup — so the lock overlay does not interrupt the next screen.
        lockManager.resetToUnlocked()
        switch appState.context {
        case .getStarted:
            appState.flow = .getStartedInfo
        default:
            // Login user re-establishing passcode after logout — KYC already done.
            UserDefaults.standard.set(true, forKey: "kycCompleted")
            appState.flow = .home
        }
    }
}




//onVerify: { _ in
//                            appState.flow = .setupPasscode
//                            // Skip passcode setup — go to biometric enrollment if available
//                            if lockManager.isBiometricHardwarePresent
//                                && !lockManager.isBiometricEnabled
//                                && !RSAKeyManager.shared.keysExist() {
//                                appState.flow = .enableBiometrics
//                            } else {
//                                appState.flow = .getStartedInfo
//                            }
//                        },
//                        onResend: { /* dummy — no API yet */ },

//
//    .onChangeCompat(of: appState.otpVerified) { verified in
//                guard verified else { return }
//                if lockManager.isPasscodeSet {
//                    // Returning user — KYC already completed, restore the flag cleared on logout
//                    UserDefaults.standard.set(true, forKey: "kycCompleted")
//                    appState.flow = .home
//                    Task { await pushManager.requestPermission() }
//                } else if appState.context == .getStarted {
//                    // New registration — collect email/password before security setup
//                if appState.context == .getStarted {
//                    // New registration — collect email + phone before security setup
//                    appState.flow = .signupDetails
//                } else {
//                    appState.flow = .setupPasscode
//                    // Login flow — skip passcode, enroll biometric if available
//                    UserDefaults.standard.set(true, forKey: "kycCompleted")
//                    if lockManager.isBiometricHardwarePresent && !RSAKeyManager.shared.keysExist() {
//                        appState.flow = .enableBiometrics
//                    } else {
//                        appState.flow = .home
//                    }
//                    Task { await pushManager.requestPermission() }
//                }
//            }
