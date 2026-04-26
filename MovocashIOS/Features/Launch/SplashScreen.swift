//
//  SplashScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct SplashScreen: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("splash")
                .resizable()
                .scaledToFit()
        }
        .task {
            // Clear any stale mid-KYC flag from a previous session.
            UserDefaults.standard.removeObject(forKey: "kycInProgress")

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let result = await sessionManager.restoreSession(appState: appState)

            switch result {
            case .restored:
                // Passcode confirmed — sync UserDefaults in case it was wiped by a reinstall.
                UserDefaults.standard.set(true, forKey: "kycCompleted")

                // Keychain-backed passcode is the authoritative "setup complete" indicator.
                // UserDefaults (kycCompleted) is cleared on reinstall but the Keychain persists,
                // so we trust the passcode presence over the UserDefaults flag.
                guard lockManager.isPasscodeSet else {
                    // Passcode was cleared (e.g. after a lockout reset) but tokens still exist.
                    // If RSA keys are present the server identity is intact — authenticate
                    // via biometrics and go directly home. No PIN fallback is available so
                    // a failed biometric clears the session and returns to the start.
                    guard RSAKeyManager.shared.keysExist() else {
                        await sessionManager.logout(appState: appState)
                        appState.flow = .choice
                        return
                    }
                    #if targetEnvironment(simulator)
                    // Simulator: loginWithBiometric blocks on a network call + a Face ID
                    // dialog that only responds to Hardware > Face ID menu.
                    // Go to ChoiceScreen without logging out — session is intact and
                    // the "Sign in with Face ID" button there lets the user trigger it manually.
                    appState.flow = .choice
                    #else
                    let success = await authVM.loginWithBiometric(appState: appState)
                    if !success {
                        await sessionManager.logout(appState: appState)
                        appState.flow = .choice
                    }
                    // On success: loginWithBiometric already sets appState.flow = .home
                    #endif
                    return
                }

                lockManager.evaluateOnLaunch()

                #if targetEnvironment(simulator)
                // Simulator: skip automatic biometric during splash.
                // loginWithBiometric requires a live network call + Face ID via the
                // Hardware menu, which blocks splash indefinitely and prevents the
                // PIN screen from appearing. Go straight to PIN; the biometric button
                // in AppLockView lets the user trigger Face ID manually if desired.
                appState.flow = .appLock
                #else
                // Trigger biometric while the splash is still on screen.
                // Face ID prompt appears over the splash — no intermediate screen shown.
                if lockManager.isBiometricEnabled || RSAKeyManager.shared.keysExist() {
                    let success = await authVM.loginWithBiometric(appState: appState)
                    if success {
                        lockManager.unlockAfterRSAAuth()
                        // loginWithBiometric already set appState.flow = .home
                        return
                    }
                }

                // Biometric not enrolled, failed, or cancelled → show PIN screen.
                // autoTriggerBiometric is false so Face ID is not re-prompted automatically.
                appState.flow = .appLock
                #endif

            case .keychainLocked:
                ToastManager.shared.show(
                    "Your session could not be restored. Please unlock your device and try again.",
                    style: .error,
                    position: .bottom
                )
                appState.flow = .choice

            case .notLoggedIn:
                appState.flow = .choice
            }
        }
    }
}
