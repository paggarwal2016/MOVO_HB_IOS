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
    @StateObject private var lockManager = AppContainer.lockManager
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(lockManager)
                .networkMonitor(state: appState)
                .globalToast()
                .globalAlert()
            //.sensitiveScreen() TODO: Future Implementation will check this logic
        }
    }
}
