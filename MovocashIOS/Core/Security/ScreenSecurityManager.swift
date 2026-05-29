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

    /// Reference count of active suspensions. While greater than zero the shield
    /// is fully suppressed — even on real backgrounding or recording. In-process
    /// system overlays (Face ID, passkey, Apple Wallet, Control Center) no longer
    /// need this: the shield is driven by didEnterBackground (see observeAppState),
    /// which they never trigger. This remains for trusted full-screen flows that
    /// run in their own window and want the shield fully off — currently only the
    /// KYC SDK (`KYCManager`). Counting keeps overlapping suspensions safe: the
    /// shield resumes only when the last one ends.
    private var suspensionCount = 0 {
        didSet { updateShield() }
    }

    var isProtectionSuspended: Bool { suspensionCount > 0 }

    /// Suspends the shield. Must be balanced by `endProtectionSuspension()`.
    func beginProtectionSuspension() {
        suspensionCount += 1
    }

    /// Ends one suspension. Safe to call more than its matching begin (floored
    /// at zero) so a stray restore can never leave protection permanently off.
    func endProtectionSuspension() {
        suspensionCount = max(0, suspensionCount - 1)
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
        // Use didEnterBackground / willEnterForeground rather than
        // willResignActive / didBecomeActive. willResignActive fires for any
        // system overlay (Face ID, passkey, Apple Wallet, Control Center,
        // notification pull-down, incoming calls) and would flash the shield on
        // top of them. didEnterBackground fires only on genuine backgrounding
        // (home / app switcher) and still occurs before the task-switcher
        // snapshot, so the snapshot stays protected (Apple Tech Q&A QA1838).
        let backgroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { _ in
            // Must run synchronously: the task-switcher snapshot is taken right
            // after this notification returns. Deferring via Task would show the
            // shield too late and leave the snapshot unprotected. The notification
            // is delivered on the main thread, so assumeIsolated is safe here.
            MainActor.assumeIsolated {
                ScreenSecurityManager.shared.isInBackground = true
            }
        }

        let foregroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.isInBackground = false
            }
        }

        observerTokens.append(contentsOf: [backgroundToken, foregroundToken])
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
        guard !isProtectionSuspended else {
            SecureWindowShield.shared.hide()
            return
        }

        let shouldProtect = (isCaptured && sensitiveScreenVisible) || isInBackground

        if shouldProtect {
            SecureWindowShield.shared.show()
        } else {
            SecureWindowShield.shared.hide()
        }
    }
}
