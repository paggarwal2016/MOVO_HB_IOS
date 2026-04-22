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
                // Keychain-backed passcode is the authoritative "setup complete" indicator.
                // UserDefaults (kycCompleted) is cleared on reinstall but the Keychain persists,
                // so we trust the passcode presence over the UserDefaults flag.
                guard lockManager.isPasscodeSet else {
                    // Tokens exist but no passcode — security setup was never finished.
                    // Clear the session and send the user back to the start.
                    await sessionManager.logout(appState: appState)
                    appState.flow = .choice
                    return
                }

                // Passcode confirmed — sync UserDefaults in case it was wiped by a reinstall.
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                // Ensure the lock is active — AppLockView will auto-trigger
                // biometric (RSA → local fallback) once it appears.
                lockManager.evaluateOnLaunch()
                appState.flow = .home

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
