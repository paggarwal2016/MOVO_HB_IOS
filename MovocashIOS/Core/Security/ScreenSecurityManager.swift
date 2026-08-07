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

    @Published var sensitiveScreenVisible: Bool = false {
        didSet { updateShield() }
    }

    /// Transient flag raised for a short window after a screenshot is taken. The
    /// screenshot notification fires only *after* the image is captured (the pixels
    /// are already blanked by `.secured()`), so this briefly shows the Shield as
    /// feedback, then clears itself. Kept separate from recording so overlapping
    /// events compose safely.
    private var screenshotShieldActive: Bool = false {
        didSet { updateShield() }
    }

    /// Auto-hide timer for `screenshotShieldActive`.
    private var screenshotShieldTask: Task<Void, Never>?

    /// How long the Shield stays up after a screenshot before auto-hiding.
    private let screenshotShieldDuration: TimeInterval = 2

    /// Reference count of active suspensions. While greater than zero the shield
    /// is fully suppressed — even on real backgrounding or recording. In-process
    /// system overlays (Face ID, passkey, Apple Wallet, Control Center) no longer
    /// need this: the shield is driven only by active screen capture (recording /
    /// screenshot), which they never trigger. This remains for trusted full-screen
    /// flows that run in their own window and want the shield fully off — currently only the
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

    func observeScreenshot() {
        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                ScreenSecurityManager.shared.handleScreenshot()
                await ScreenSecurityManager.shared.onScreenshotDetected?()
            }
        }
        observerTokens.append(token)
    }
}

// MARK: - Shield Control
private extension ScreenSecurityManager {

    func updateShield() {
        guard AppConfig.isScreenProtectionEnabled else {
            // Protection disabled via AppConfig: this manager never SHOWS the
            // shield (recording / app switcher show the live screen). It also must
            // not hide it here — the same window is reused as the biometric-auth
            // cover, driven by AppLockManager. Hiding on foreground would tear that
            // cover down before authentication completes.
            return
        }

        guard !isProtectionSuspended else {
            SecureWindowShield.shared.hide(.protection)
            return
        }

        // Backgrounding no longer raises the Shield — AppLockManager covers the app
        // with the SplashScreen on background. The Shield is reserved for active
        // screen capture: a live recording, or the brief window after a screenshot.
        let shouldProtect = (isCaptured && sensitiveScreenVisible) || screenshotShieldActive

        if shouldProtect {
            SecureWindowShield.shared.show(.protection)
        } else {
            SecureWindowShield.shared.hide(.protection)
        }
    }

    /// Raises the Shield briefly after a screenshot, then auto-hides it. A fresh
    /// screenshot restarts the timer so back-to-back captures keep the Shield up.
    func handleScreenshot() {
        screenshotShieldTask?.cancel()
        screenshotShieldActive = true
        screenshotShieldTask = Task { [weak self] in
            guard let self else { return }
            let seconds = UInt64(self.screenshotShieldDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: seconds)
            guard !Task.isCancelled else { return }
            self.screenshotShieldActive = false
        }
    }
}
