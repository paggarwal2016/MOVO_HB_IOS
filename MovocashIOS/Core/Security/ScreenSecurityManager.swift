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

    var onScreenshotDetected: (() async -> Void)?

    private var observerTokens: [NSObjectProtocol] = []

    private init() {
        observeRecording()
        observeAppState()
        observeScreenshot()
    }

    deinit {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - Observers
private extension ScreenSecurityManager {

    func observeRecording() {
        let token = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isCaptured = UIScreen.main.isCaptured
            }
        }
        observerTokens.append(token)
    }

    func observeAppState() {
        let resignToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isInBackground = true
            }
        }

        let activeToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isInBackground = false
            }
        }

        observerTokens.append(contentsOf: [resignToken, activeToken])
    }

    func observeScreenshot() {
        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                await ScreenSecurityManager.shared.onScreenshotDetected?()
            }
        }
        observerTokens.append(token)
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
