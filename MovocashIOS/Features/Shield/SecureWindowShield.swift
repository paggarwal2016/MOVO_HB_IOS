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
//  Content is chosen per active reason, not globally:
//    • .protection active → ShieldView (the "Screen Protected" message shown
//      during a screenshot or screen recording).
//    • otherwise (only .auth) → the app SplashScreen, a seamless backdrop for
//      backgrounding and the biometric gate's splash mode.
//  The hosted content is refreshed whenever the active reasons change, so a
//  window already up for one reason switches content if the other is added.
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
    private var host: UIHostingController<AnyView>?

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
            // Reasons may have changed while the window was already up (e.g. a
            // screenshot fires .protection over an existing .auth cover), so keep
            // the hosted content in sync with the current reason set.
            host?.rootView = coverContent
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

        self.host = host
        secureWindow = window
    }

    private func dismiss() {
        secureWindow?.isHidden = true
        secureWindow = nil
        host = nil
    }

    /// ShieldView (the "Screen Protected" message) only while screen protection is
    /// active — i.e. during a screenshot or screen recording. Otherwise the app
    /// SplashScreen, which hides content on backgrounding and is pixel-identical to
    /// BiometricGateView's splash backdrop.
    private var coverContent: AnyView {
        if reasons.contains(.protection) {
            return AnyView(ShieldView())
        } else {
            return AnyView(SplashScreen())
        }
    }
}
