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
    @StateObject private var userVM      = AppContainer.shared.makeUserViewModel()
    
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
                        onEnable: { // TODO: - Testing checking
                            Task { await authVM.enrollRSASilently(appState: appState) }
                            advanceAfterSecurity()
                        },  // enabled  → home or kyc
                        onSkip:   {
                            Task { await authVM.enrollRSASilently(appState: appState) }
                            advanceAfterSecurity()
                        }   // skipped  → home or kyc
                    )
                    
                case .kyc:
                    KYCView()
                    
                case .home:
                    HomeTabBarView()
                }
            }
            .environmentObject(authVM)
            .environmentObject(userVM)
            .environmentObject(lockManager)
            .environmentObject(AppContainer.shared.sessionManager)
            .animation(.easeInOut, value: appState.flow)
            
            // ── Lock overlay (returning users / background lock) ───────────
            // Suppressed during new-user registration arrival to prevent
            // spurious lock overlays caused by KYC UIViewController teardown.
            if lockManager.state == .locked && !appState.isNewRegistration {
                AppLockView(vm: lockVM, autoTriggerBiometric: false)
                    .transition(.opacity)
                    .zIndex(10)
                    .ignoresSafeArea()
            }
        }
        .onChangeCompat(of: scenePhase) { newPhase in lockManager.handleScenePhase(newPhase) }
        .onChangeCompat(of: appState.otpVerified) { verified in
            guard verified else { return }
            if lockManager.isPasscodeSet {
                // Returning user — passcode already set, lock overlay handles unlock
                appState.flow = .home
            } else {
                // New user or first login — go through security setup
                appState.flow = .setupPasscode
            }
        }
        .onChangeCompat(of: lockManager.requiresPhoneLogin) { required in
            guard required else { return }
            Task {
                await AppContainer.shared.sessionManager.logout(appState: appState)
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
        case PhoneFlowType.getStarted.rawValue:   // "registration"
            appState.flow = .kyc
        default:                                  // "login" or anything else
            appState.flow = .home
        }
    }
}
