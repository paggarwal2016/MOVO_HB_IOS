//
//  IdleTimerManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/07/26.
//

import Foundation

/// Detects in-app inactivity and fires `.sessionExpired` after 15 minutes of no
/// user interaction. Only active while the user is on the home dashboard.
///
/// **Lifecycle:** `start()` / `stop()` are the authoritative on/off switch; RootView
/// calls them via `onChangeCompat(of: appState.flow)`. `checkIdle()` also guards on
/// `kycCompleted` as a defence-in-depth safety net — if that guard fires when the
/// timer should already be stopped, it logs a warning so the divergence is visible.
///
/// **Activity detection:** RootView's root-level `simultaneousGesture` calls
/// `recordActivity()` on every touch without consuming other gestures. It also calls
/// `recordActivity()` on scene-phase `.active`, so time spent in the background is
/// excluded from the idle clock. Background-period expiry is handled separately by
/// `AppLockManager.handleScenePhase`.
///
/// **Clock note:** idle time is measured with `Date()` (wall clock). NTP skew is
/// sub-second and negligible for a 15-minute window. No monotonic-clock pattern
/// exists elsewhere in the codebase; using `Date()` is consistent with the rest of
/// the app (`AppLockManager.SystemClock`, `SessionManager` JWT expiry).
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
        // Timer(timeInterval:) does NOT auto-schedule, so we control the run-loop
        // mode explicitly. scheduledTimer would auto-add in .default and then
        // RunLoop.main.add(forMode: .common) would register a second time — causing
        // the timer to fire from both modes (double 60s ticks).
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    /// Stop idle monitoring. Called when leaving the home dashboard.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func checkIdle() {
        // start()/stop() is the authoritative lifecycle. This guard is a
        // defence-in-depth safety net: if the timer is somehow still running after
        // the user left .home (e.g. a missed stop() call), suppress the expiry and
        // log a warning so the divergence is visible rather than silent.
        guard UserDefaults.standard.bool(forKey: "kycCompleted") else {
            SecureLogger.warning(
                "IdleTimerManager.checkIdle() fired with kycCompleted=false — timer should have been stopped. Suppressing.",
                category: .auth
            )
            stop()
            return
        }
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
