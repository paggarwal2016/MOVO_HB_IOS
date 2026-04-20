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
                let kycCompleted = UserDefaults.standard.bool(forKey: "kycCompleted")

                guard kycCompleted else {
                    // KYC not finished — log out silently and restart from the beginning.
                    lockManager.logout()
                    await sessionManager.logout(appState: appState)
                    appState.flow = .choice
                    return
                }

                if lockManager.state != .unlocked {
                    lockManager.evaluateOnLaunch()
                }
                if lockManager.state == .locked {
                    let rsaSuccess = await authVM.loginWithBiometric(appState: appState)
                    if rsaSuccess {
                        lockManager.unlockAfterRSAAuth()
                    } else {
                        await lockManager.unlockWithBiometric()
                    }
                }
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
