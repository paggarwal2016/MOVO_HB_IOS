//
//  MOVO_HB_IOSApp.swift
//  MOVO_HB_IOS
//
//  Created by Vinu on 23/02/26.
//

import SwiftUI

@main
struct MOVO_HB_IOSApp: App {
    var body: some Scene {
        WindowGroup {
            // TODO: - Enable future
//            if JailbreakDetector.shared.isJailBroken {
//                fatalError("Jailbroken device detected.")
//            }
            PhoneInputView()
        }
    }
}
