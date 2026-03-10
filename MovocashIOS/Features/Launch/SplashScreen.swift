//
//  SplashScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI
//
//struct SplashScreen: View {
//    
//    @EnvironmentObject var appState: AppState
//    @EnvironmentObject var lockManager: AppLockManager
//    
//    var body: some View {
//        ZStack {
//            Color.white
//                .ignoresSafeArea()
//            
//            Image("splash")
//                .resizable()
//                .scaledToFit()
//        }
//        .task {
//            try? await Task.sleep(nanoseconds: 2_000_000_000)
//            
//            let restored = await AppContainer.shared.sessionManager
//                .restoreSession(appState: appState)
//            
//            if restored {
//                // Session exists → show home, then let the lock overlay cover it
//                appState.flow = .home
//                lockManager.evaluateOnLaunch()   // will set state = .locked if passcode set
//            } else {
//                appState.flow = .choice
//            }
//        }
//    }
//}


//
//  SplashScreen.swift
//  MovocashIOS
//

import SwiftUI

struct SplashScreen: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("splash")
                .resizable()
                .scaledToFit()
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let restored = await AppContainer.shared.sessionManager
                .restoreSession(appState: appState)

            guard restored else {
                appState.flow = .choice
                return
            }

            appState.flow = .home

            // Lock silently — DO NOT auto-trigger biometric yet
            lockManager.evaluateOnLaunch()

            // We drive the single biometric attempt from here,
            // so AppLockView must NOT fire its own on appear.
            if lockManager.state == .locked {
                await lockManager.unlockWithBiometric()
            }
        }
    }
}
