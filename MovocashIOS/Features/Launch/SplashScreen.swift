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

            let restored = await sessionManager
                .restoreSession(appState: appState)

            guard restored else {
                appState.flow = .choice
                return
            }

            lockManager.evaluateOnLaunch()
            appState.flow = .home

            if lockManager.state == .locked {
                await lockManager.unlockWithBiometric()
            }
            
        }
    }
}
