//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

@main
struct MovocashIOSApp: App {
    @State private var isDeviceCompromised = false
    
    init() {
        _ = ScreenSecurityManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            // MAIN CONTENT
            Group {
                if isDeviceCompromised {
                    CompromisedDeviceView() // Blocked UI
                } else {
                    PhoneInputView()        // Normal app content
                        .globalAlert()
                        .sensitiveScreen()
                }
            }
            .task {
                await checkDeviceSecurity()
            }
        }
    }
    
    // MARK: - Async Security Check
    private func checkDeviceSecurity() async {
        let compromised = await JailbreakDetector.shared.isJailBroken
        if compromised {
            await forceLogoutAndBlockUI()
        }
    }
    
    // MARK: - Handle Compromised Device - Show blocked UI - forceLogout
    @MainActor
    private func forceLogoutAndBlockUI() async {
        // TODO: - AuthManager.shared.logout()
        //        await AuthManager.shared.logout()    // Actor-safe logout
        //        try? await KeychainManager.shared.deleteAll() // optional: clear tokens
        self.isDeviceCompromised = true
        SecureLogger.log("Device is compromised. User forced to logout.")
    }
}
