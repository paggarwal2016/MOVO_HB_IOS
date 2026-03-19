//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI
import Combine

@main
struct MovocashIOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var lockManager = AppContainer.shared.lockManager
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(lockManager)
                .networkMonitor(state: appState)
                .globalToast()
                .globalAlert()
                .task {
                    // On first launch after install, evaluate whether to lock
                    // SplashScreen handles session restore; lock eval happens after
                    lockManager.evaluateOnLaunch()
                }
            //.sensitiveScreen() TODO: Future Implementation will check this logic
        }
    }
}
