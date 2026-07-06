//
//  IdleTimerManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/07/26.
//

import Foundation

/// Detects in-app foreground inactivity and fires `.sessionExpired` after 15 minutes
/// of no user interaction. Only active while the user is on the home dashboard
/// (kycCompleted == true). The timer is started/stopped by RootView as the flow
/// enters and leaves `.home`.
///
/// Activity is reported by RootView's root-level `simultaneousGesture`, which catches
/// all touch events without cancelling existing gesture recognizers.
@MainActor
final class IdleTimerManager: ObservableObject {

    private var lastActivityDate: Date = Date()
    private var timer: Timer?

    private let timeout: TimeInterval = AppState.apiIdleTimeout   // 15 min

    // MARK: - Interface

    /// Reset the idle clock. Called on every detected touch in the app.
    func recordActivity() {
        lastActivityDate = Date()
    }

    /// Begin idle monitoring. Called when the home dashboard appears.
    /// Safe to call multiple times — only one timer runs at a time.
    func start() {
        guard timer == nil else { return }
        lastActivityDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stop idle monitoring. Called when leaving the home dashboard.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func checkIdle() {
        guard UserDefaults.standard.bool(forKey: "kycCompleted") else { return }
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        guard elapsed >= timeout else { return }
        SecureLogger.info(
            "Foreground idle \(Int(elapsed))s → sessionExpired",
            category: .auth
        )
        stop()
        NotificationCenter.default.post(
            name: .sessionExpired,
            object: nil,
            userInfo: ["message": "Your session has expired due to inactivity. Please sign in again."]
        )
    }
}
