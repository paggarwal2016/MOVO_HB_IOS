//
//  SecureWindowShield.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//
//  Single top-most window (`windowLevel = .alert + 1`) reused for two purposes,
//  tracked as independent "reasons" so the two subsystems never fight over it:
//
//    • .protection — screenshot / recording / app-switcher shield. Driven by
//      ScreenSecurityManager. Shows ShieldView (the "Screen Protected" message).
//
//    • .auth — biometric-resume cover. Driven by AppLockManager. Hides the
//      previous screen on foreground until Face ID completes.
//
//  The window stays visible while ANY reason is active and is removed only when
//  all reasons clear. The system biometric prompt renders above this window, so
//  the gate always appears on top when authentication is required.
//
//  Content: when screen protection is enabled the cover is ShieldView (so the
//  protection message shows first); otherwise it's the app SplashScreen (a
//  seamless backdrop for the biometric gate's splash mode).
//

import UIKit
import SwiftUI

@MainActor
final class SecureWindowShield {

    static let shared = SecureWindowShield()
    private init() {}

    /// Why the cover is currently up. The window shows while this is non-empty.
    enum Reason {
        case protection   // screenshot / recording / background shield
        case auth         // biometric-resume cover
    }

    private var reasons: Set<Reason> = []
    private var secureWindow: UIWindow?

    /// Raise the cover for `reason` (idempotent).
    func show(_ reason: Reason) {
        reasons.insert(reason)
        update()
    }

    /// Release `reason`; the cover comes down only once no reasons remain.
    func hide(_ reason: Reason) {
        reasons.remove(reason)
        update()
    }

    private func update() {
        if reasons.isEmpty {
            dismiss()
        } else {
            present()
        }
    }

    private func present() {
        guard secureWindow == nil,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .black

        let host = UIHostingController(rootView: coverContent)
        host.view.backgroundColor = .black

        window.rootViewController = host
        window.isHidden = false

        secureWindow = window
    }

    private func dismiss() {
        secureWindow?.isHidden = true
        secureWindow = nil
    }

    /// ShieldView (protection message) when screen protection is on; otherwise the
    /// app SplashScreen, which is pixel-identical to BiometricGateView's splash.
    @ViewBuilder
    private var coverContent: some View {
        if AppConfig.isScreenProtectionEnabled {
            ShieldView()
        } else {
            SplashScreen()
        }
    }
}
