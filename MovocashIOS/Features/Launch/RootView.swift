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
                    OTPScreen(authVM: authVM)

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
                            if lockManager.isBiometricAvailable {
                                appState.flow = .enableBiometrics
                            } else {
                                appState.flow = .setupPasscode
                            }
                        },
                        onContinue: {
                            appState.flow = .kyc
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
            if lockManager.state == .locked && !appState.isNewRegistration && !UserDefaults.standard.bool(forKey: "kycInProgress") {
                AppLockView(vm: lockVM, autoTriggerBiometric: false)
                    .transition(.opacity)
                    .zIndex(10)
                    .ignoresSafeArea()
            }
        }
        .onChangeCompat(of: scenePhase) { newPhase in lockManager.handleScenePhase(newPhase) }
        .task(id: appState.flow) {
            guard appState.flow == .kyc else { return }
            UserDefaults.standard.set(true, forKey: "kycInProgress")
            await kycVM.startVerification {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
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
                // Returning user — passcode already set, lock overlay handles unlock
                appState.flow = .home
            } else {
                // New user or first login — go through security setup
                appState.flow = .setupPasscode
            }
            Task { await pushManager.requestPermission() }
        }
        .onChangeCompat(of: lockManager.requiresPhoneLogin) { required in
            guard required else { return }
            Task {
                await sessionManager.logout(appState: appState)
                lockManager.logout()
                appState.flow = .loginPhone
            }
        }
    }

    // MARK: -

    /// After biometric step:
    /// registration → KYC  |  login (KYC already done) → Home
    private func advanceAfterSecurity() {
        switch appState.context {
        case .getStarted:
            appState.flow = .pickDocument
        default:
            appState.flow = .home
        }
    }
}
