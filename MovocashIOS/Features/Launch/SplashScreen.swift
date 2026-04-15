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
            // If app was killed mid-KYC, logout immediately before anything else
            if UserDefaults.standard.bool(forKey: "kycInProgress") {
                UserDefaults.standard.removeObject(forKey: "kycInProgress")
                lockManager.logout()
                await sessionManager.logout(appState: appState)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                appState.flow = .choice
                return
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let result = await sessionManager.restoreSession(appState: appState)

            switch result {
            case .restored:
                // Only enforce the launch lock if the user hasn't already
                // authenticated during the splash delay — prevents a double
                // passcode prompt when the user unlocks before restoreSession returns.
                if lockManager.state != .unlocked {
                    lockManager.evaluateOnLaunch()
                }

                if lockManager.state == .locked {
                    // Step 1: GET /rsa/nonce → Step 2: Face ID signs → Step 3: POST /auth/token-rsa
                    // APIs complete first. Home screen shows only after success.
                    let rsaSuccess = await authVM.loginWithBiometric(appState: appState)
                    if rsaSuccess {
                        lockManager.unlockAfterRSAAuth()
                    } else {
                        // No RSA keys or server error — fall back to local biometric
                        await lockManager.unlockWithBiometric()
                    }
                }

                // Navigate to home only after auth (RSA or local) completes
                appState.flow = .home

            case .keychainLocked:
                // Tokens exist but keychain is locked — device rebooted and not yet
                // unlocked. Inform the user and fall back to login rather than
                // silently appearing as if they were never logged in.
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
