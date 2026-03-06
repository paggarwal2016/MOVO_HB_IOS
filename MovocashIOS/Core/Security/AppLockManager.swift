//
//  AppLockManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import SwiftUI

@MainActor
final class AppLockManager {

    static let shared = AppLockManager()

    private init() {}

    private var lastBackgroundTime: Date?

    private let timeout: TimeInterval = 30

    func didEnterBackground() {
        lastBackgroundTime = Date()
    }

    func handleAppReentry(appState: AppState) async {

        guard let last = lastBackgroundTime else { return }

        let elapsed = Date().timeIntervalSince(last)

        guard elapsed > timeout else { return }

        guard appState.flow == .home else { return }

        do {
            let success = try await BiometricManager.shared.authenticate(
                reason: "Authenticate to access your account"
            )

            if !success {
                appState.flow = .choice
            }

        } catch {
            appState.flow = .choice
        }
    }
}
