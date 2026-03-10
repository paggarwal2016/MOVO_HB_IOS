//
//  RootView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var authVM      = AppContainer.shared.makeAuthViewModel()
    @StateObject private var lockManager = AppContainer.lockManager
    @StateObject private var lockVM      = AppContainer.shared.makeAppLockViewModel()

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
                        vm: {
                            let vm = AppLockViewModel(lockManager: lockManager)
                            vm.isSetupMode = true   // routes appendDigit → setupFlow
                            return vm
                        }(),
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

                case .kyc:
                    KYCView()

                case .home:
                    HomeTabBarView()
                }
            }
            .environmentObject(authVM)
            .environmentObject(lockManager)
            .environmentObject(AppContainer.shared.sessionManager)
            .animation(.easeInOut, value: appState.flow)

            // ── Lock overlay (returning users / background lock) ───────────
            if lockManager.state == .locked {
                AppLockView(vm: lockVM, autoTriggerBiometric: false)
                    .transition(.opacity)
                    .zIndex(10)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { lockManager.handleScenePhase($0) }
        .onChange(of: appState.otpVerified) { verified in
            guard verified else { return }
            if lockManager.isPasscodeSet {
                // Returning user — passcode already set, lock overlay handles unlock
                appState.flow = .home
            } else {
                // New user or first login — go through security setup
                appState.flow = .setupPasscode
            }
        }
    }

    // MARK: -

    /// After biometric step:
    /// registration → KYC  |  login (KYC already done) → Home
    private func advanceAfterSecurity() {
        switch appState.context {
        case PhoneFlowType.getStarted.rawValue:   // "registration"
            appState.flow = .kyc
        default:                                  // "login" or anything else
            appState.flow = .home
        }
    }
}
