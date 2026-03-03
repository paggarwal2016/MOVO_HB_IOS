//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

@main struct MovocashIOSApp: App {
    @State private var isDeviceCompromised = false
    
//    init() { TODO: // In future
//        _ = ScreenSecurityManager.shared
//    }
    
    var body: some Scene { WindowGroup { ZStack {
        //Match Launch screen color
        LinearGradient( colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing )
            .ignoresSafeArea()
        Group {
            if isDeviceCompromised {
                CompromisedDeviceView()
            } else {
                PhoneInputView()
                    .globalAlert()
                    //.sensitiveScreen() TODO: // In future
            }
        }
    }
    .task {
        await checkDeviceSecurity()
    }
    }
    }
    private func checkDeviceSecurity() async {
        let compromised = await JailbreakDetector.shared.isJailBroken
        if compromised {
            await forceLogoutAndBlockUI()
        }
    }
    @MainActor private func forceLogoutAndBlockUI() async {
        self.isDeviceCompromised = true
        SecureLogger.info("Device is compromised. User forced to logout.", category: .general)
    }
}
