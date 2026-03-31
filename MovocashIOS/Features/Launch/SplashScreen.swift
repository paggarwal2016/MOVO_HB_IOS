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
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let result = await sessionManager.restoreSession(appState: appState)

            switch result {
            case .restored:
                lockManager.evaluateOnLaunch()
                appState.flow = .home
                if lockManager.state == .locked {
                    await lockManager.unlockWithBiometric()
                }

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
