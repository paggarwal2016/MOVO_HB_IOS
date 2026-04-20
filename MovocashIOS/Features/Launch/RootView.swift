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
    @EnvironmentObject private var lockVM: AppLockViewModel
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var pushManager: PushManager

    /// Passed directly — NOT via environment — to avoid AppLockViewModel type
    /// collision with lockVM which would cause SwiftUI to serve the wrong instance.
    @ObservedObject var passcodeSetupVM: AppLockViewModel
    @ObservedObject var kycVM: KYCViewModel

    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {

            // ── Main flow ──────────────────────────────────────────────────
            NavigationStack {
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
                                appState.otpVerified = true
                                appState.flow = destination
                            }
                        },
                        onResend: {
                            try await authVM.sendOTP()
                        },
                        onBack: {
                            UIApplication.shared.dismissKeyboard()
                            appState.flow = appState.context == .login ? .loginPhone : .getStartedPhone
                        }
                    )

                case .signupDetails:
                    SignUpScreen(
                        onBack: { appState.flow = .choice },
                        onContinue: { appState.flow = .emailOTP },
                        onSignIn: { appState.flow = .loginPhone }
                    )

                case .emailOTP:
                    OTPScreen(
                        title: "Verify email",
                        subtitle: "A 4-digit verification code was sent to your email",
                        maxLength: 4,
                        isLoading: false,
                        onVerify: { _ in
                            appState.flow = .getStartedInfo
                        },
                        onResend: { /* dummy — no API yet */ },
                        onBack: { appState.flow = .signupDetails }
                    )

                case .getStartedInfo:
                    GetStartedInfoScreen(
                        onReady: {
                            appState.flow = .pickDocument
                        },
                        onNotNow: {
                            Task {
                                await sessionManager.logout(appState: appState)
                                appState.flow = .choice
                            }
                        },
                        onBack: { appState.flow = .emailOTP }
                    )

                    // ── Step 1: set + confirm passcode ─────────────────────────
                case .setupPasscode:
                    PasscodeSetupView(
                        vm: passcodeSetupVM,
                        onSuccess: {
                            // Passcode confirmed — move to biometric opt-in
                            if lockManager.isBiometricAvailable {
                                appState.flow = .enableBiometrics
                            } else {
                                advanceAfterSecurity()
                            }
                        }
                    )

                    // ── Step 2: biometric opt-in ───────────────────────────────
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
                            appState.flow = .setupPasscode
                            Task { await pushManager.requestPermission() }
                        }
                    )

                case .kyc:
                    EmptyView()

                case .home:
                    HomeTabBarView()
                }
            }
            .environmentObject(authVM)
            .environmentObject(userVM)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
            .animation(.easeInOut, value: appState.flow)

            // ── Lock overlay (returning users / background lock) ───────────
            // Suppressed during new-user registration arrival to prevent
            // spurious lock overlays caused by KYC UIViewController teardown.
            if lockManager.state == .locked && appState.flow != .splash && !appState.isNewRegistration && !UserDefaults.standard.bool(forKey: "kycInProgress") {
                AppLockView(vm: lockVM, autoTriggerBiometric: false)
                    .transition(.opacity)
                    .zIndex(10)
                    .ignoresSafeArea()
            }
        }
        .onChangeCompat(of: scenePhase) { newPhase in
            lockManager.handleScenePhase(newPhase)
            // If the app returns to foreground while still locked, discard any
            // partially entered digits so the user starts fresh.
            if newPhase == .active, lockManager.state == .locked {
                lockVM.clearInput()
            }
        }
        .task(id: appState.flow) {
            guard appState.flow == .kyc else { return }
            UserDefaults.standard.set(true, forKey: "kycInProgress")
            await kycVM.startVerification {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                appState.isNewRegistration = true
                appState.flow = .home
            } onFailure: {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
                appState.flow = .pickDocument
            }
        }
        .onChangeCompat(of: appState.otpVerified) { verified in
            guard verified else { return }
            if lockManager.isPasscodeSet {
                // Returning user — KYC already completed, restore the flag cleared on logout
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                appState.flow = .home
                Task { await pushManager.requestPermission() }
            } else if appState.context == .getStarted {
                // New registration — collect email/password before security setup
                appState.flow = .signupDetails
            } else {
                appState.flow = .setupPasscode
                Task { await pushManager.requestPermission() }
            }
        }
        .onChangeCompat(of: lockManager.requiresPhoneLogin) { required in
            guard required else { return }
            Task {
                await sessionManager.logout(appState: appState)
                lockManager.logout()
                appState.flow = .loginPhone
            }
        }
        .onAppear {
            // APIs execute first (GET /rsa/nonce → sign → POST /auth/token-rsa).
            // Returns true so submitBiometric unlocks silently after success.
            lockVM.onBiometricSuccess = {
                await authVM.loginWithBiometric(appState: appState)
            }
        }
    }

    // MARK: -

    /// After biometric step:
    /// registration → KYC  |  login (KYC already done) → Home
    private func advanceAfterSecurity() {
        switch appState.context {
        case .getStarted:
            appState.flow = .kyc
        default:
            // Login user re-establishing passcode after logout — KYC already done.
            UserDefaults.standard.set(true, forKey: "kycCompleted")
            appState.flow = .home
        }
    }
}
