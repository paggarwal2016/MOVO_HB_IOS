//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

@main
struct MovocashIOSApp: App {
    // State to track if device is compromised
    @State private var isDeviceCompromised = false
    
    init() {
        // Check for jailbreak/root at launch
        if JailbreakDetector.shared.isJailBroken {
            handleCompromisedDevice()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isDeviceCompromised {
                CompromisedDeviceView() // Show warning / block UI
            } else {
                PhoneInputView() // Normal app content
                    .globalAlert()
            }
        }
    }
    
    private func handleCompromisedDevice() {
        // Clear sensitive data
        // TODO: - AuthManager.shared.logout()
        
        // Set state to show warning UI
        DispatchQueue.main.async {
            self.isDeviceCompromised = true
        }
        
        // Optional: Log analytics for security monitoring
    }
}
