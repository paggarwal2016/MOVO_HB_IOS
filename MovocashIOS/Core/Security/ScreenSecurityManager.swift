//
//  ScreenSecurityManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class ScreenSecurityManager: ObservableObject {

    static let shared = ScreenSecurityManager()

    @Published private(set) var isCaptured: Bool = UIScreen.main.isCaptured {
        didSet { updateShield() }
    }

    @Published private(set) var isInBackground: Bool = false {
        didSet { updateShield() }
    }

    @Published var sensitiveScreenVisible: Bool = false {
        didSet { updateShield() }
    }

    private init() {
        observeRecording()
        observeAppState()
        observeScreenshot()
    }
}

// MARK: - Observers
private extension ScreenSecurityManager {

    func observeRecording() {
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isCaptured = UIScreen.main.isCaptured
            }
        }
    }

    func observeAppState() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isInBackground = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isInBackground = false
            }
        }
    }

    func observeScreenshot() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                await AuthManager.shared.clearSession()
            }
        }
    }
}

// MARK: - Shield Control
private extension ScreenSecurityManager {

    func updateShield() {
        let shouldProtect = (isCaptured && sensitiveScreenVisible) || isInBackground

        if shouldProtect {
            SecureWindowShield.shared.show()
        } else {
            SecureWindowShield.shared.hide()
        }
    }
}
