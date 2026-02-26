//
//  SecureWindowShield.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import UIKit
import SwiftUI

@MainActor
final class SecureWindowShield {

    static let shared = SecureWindowShield()
    private var secureWindow: UIWindow?

    func show() {
        guard secureWindow == nil,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .black

        let host = UIHostingController(rootView: ShieldView())
        host.view.backgroundColor = .black

        window.rootViewController = host
        window.isHidden = false

        secureWindow = window
    }

    func hide() {
        secureWindow?.isHidden = true
        secureWindow = nil
    }
}
