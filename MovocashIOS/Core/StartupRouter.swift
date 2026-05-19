//
//  StartupRouter.swift
//  MovocashIOS
//
//  Synchronous cold-launch router. Decides AppState.pendingDestination from Keychain +
//  UserDefaults before WindowGroup renders. postBootstrap enforces a minimum splash
//  duration for visual stability, then transitions flow to pendingDestination.
//

import Foundation

@MainActor
enum StartupRouter {

    // MARK: - Synchronous bootstrap (called from @main App.init)

    static func bootstrap(
        appState: AppState,
        keychain: KeychainManagerProtocol,
        lockManager: AppLockManager
    ) {
        UserDefaults.standard.removeObject(forKey: "kycInProgress")

        // AppLockManager.init() locks eagerly whenever a passcode exists in the
        // keychain (which persists across app deletion on iOS). Reset here so the
        // lock is only re-engaged for paths that genuinely need it. The only path
        // that re-locks is section 5 (returning user) via evaluateOnLaunch().
        lockManager.resetToUnlocked()

        // ── 1. Token presence ─────────────────────────────────────────────
        let token: String
        switch keychain.getSync("access_token") {
        case .found(let value) where !value.isEmpty:
            token = value
        case .locked:
            SecureLogger.warning("Boot: keychain locked since reboot", category: .auth)
            deferToast(after: AppState.splashMinDuration) {
                ToastManager.shared.show(
                    "Your session could not be restored. Please unlock your device and try again.",
                    style: .error,
                    position: .bottom
                )
            }
            appState.pendingDestination = .choice
            return
        case .found, .missing:
            SecureLogger.info("Boot route → .choice (no token)", category: .auth)
            appState.pendingDestination = .choice
            return
        }
        _ = token

        // ── 2. Server idle-timeout gate (PIN-only users) ──────────────────
        let lastActivity = UserDefaults.standard.double(forKey: "lastActivityAt")
        let hasRSA = RSAKeyManager.shared.keysExist()

        // If a token exists but no activity was ever recorded, this is leftover state
        // from a previous install — iOS keychain persists across app deletion, but
        // UserDefaults does not. Silently clear and route to choice. No toast, since
        // the user has no expectation of being logged in.
        // Exception: if RSA keys also persisted, fall through to optimistic routing
        // and proceed to home — biometric login is available for sensitive actions.
        if lastActivity == 0 && !hasRSA {
            SecureLogger.info("Boot route → .choice (stale token, no activity record, no RSA)", category: .auth)
            keychain.clearAuthTokens()
            UserDefaults.standard.removeObject(forKey: "kycCompleted")
            appState.pendingDestination = .choice
            return
        }

        // Apply the idle-timeout gate only when we have real activity history.
        if lastActivity > 0 {
            let elapsedSinceActivity = Date().timeIntervalSince1970 - lastActivity
            let serverSessionLikelyDead = elapsedSinceActivity >= AppState.apiIdleTimeout

            if serverSessionLikelyDead && !hasRSA {
                SecureLogger.info(
                    "Boot route → .choice (idle \(Int(elapsedSinceActivity))s, no RSA)",
                    category: .auth
                )
                keychain.clearAuthTokens()
                UserDefaults.standard.removeObject(forKey: "kycCompleted")
                UserDefaults.standard.removeObject(forKey: "lastActivityAt")
                deferToast(after: AppState.splashMinDuration) {
                    ToastManager.shared.show(
                        "Your session has expired. Please sign in again.",
                        style: .warning,
                        position: .bottom
                    )
                }
                appState.pendingDestination = .choice
                return
            }
        }

        // ── 3. Optimistic auth ────────────────────────────────────────────
        appState.isAuthenticated = true

        let kycCompleted = UserDefaults.standard.bool(forKey: "kycCompleted")

        // ── 4. Mid-onboarding restoration ─────────────────────────────────
        guard kycCompleted else {
            let bgAt = UserDefaults.standard.double(forKey: "onboardingBackgroundedAt")
            let elapsed: TimeInterval = bgAt > 0
                ? Date().timeIntervalSince1970 - bgAt
                : 0
            UserDefaults.standard.removeObject(forKey: "onboardingBackgroundedAt")

            if elapsed >= AppState.onboardingInactivityTimeout {
                SecureLogger.info("Boot route → .choice (onboarding idle \(Int(elapsed))s)", category: .auth)
                keychain.clearAuthTokens()
                appState.isAuthenticated = false
                appState.pendingDestination = .choice
                return
            }

            if let raw = UserDefaults.standard.string(forKey: "onboardingLastScreen"),
               let savedFlow = AuthFlow(rawValue: raw) {
                lockManager.resetToUnlocked()
                if let ctxRaw = UserDefaults.standard.string(forKey: "onboardingContext") {
                    appState.pendingContext = PhoneFlowType(rawValue: ctxRaw)
                }
                SecureLogger.info("Boot route → \(savedFlow.rawValue) (mid-onboarding)", category: .auth)
                appState.pendingDestination = savedFlow
                return
            }

            SecureLogger.info("Boot route → .choice (no restorable screen)", category: .auth)
            keychain.clearAuthTokens()
            appState.isAuthenticated = false
            appState.pendingDestination = .choice
            return
        }

        // ── 5. Post-dashboard returning user ──────────────────────────────
        UserDefaults.standard.set(true, forKey: "kycCompleted")
        if hasRSA {
            SecureLogger.info("Boot route → .appLock (biometric gate)", category: .auth)
            appState.pendingDestination = .appLock
        } else {
            // No biometric enrolled. Force phone-OTP re-auth on every cold launch
            // so force-quit + relaunch never grants dashboard access without
            // explicit auth. kycCompleted stays TRUE so post-OTP lands on Home.
            SecureLogger.info("Boot route → .choice (no biometric, force re-auth)", category: .auth)
            keychain.clearAuthTokens()
            appState.isAuthenticated = false
            appState.pendingDestination = .choice
        }
    }

    // MARK: - Async post-bootstrap warmup (called from WindowGroup .task)

    static func postBootstrap(
        appState: AppState,
        keychain: KeychainManagerProtocol,
        kycManager: KYCManagerProtocol,
        analytics: AnalyticsTracking,
        biometricAuthenticate: (() async -> Bool)? = nil
    ) async {
        guard !appState.hasCompletedBootstrap else { return }
        appState.hasCompletedBootstrap = true

        let start = Date()

        if appState.isAuthenticated {
            if case .found(let token) = keychain.getSync("access_token") {
                analytics.identifyUser(from: token)
            }

            let kycCompleted = UserDefaults.standard.bool(forKey: "kycCompleted")
            if !kycCompleted {
                do {
                    try await kycManager.configureSDK(officeId: AppConfig.officeId)
                    SecureLogger.info("KYC SDK warmup complete", category: .auth)
                } catch {
                    SecureLogger.error(
                        "KYC SDK warmup failed: \(error.localizedDescription) — will retry on .kyc entry",
                        category: .auth
                    )
                }
            } else {
                SecureLogger.info("Skipping KYC SDK warmup — kycCompleted=true", category: .auth)
            }
        }

        // Enforce minimum splash duration for visual stability
        let elapsed = Date().timeIntervalSince(start)
        let remaining = AppState.splashMinDuration - elapsed
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        // If biometric gate is pending, attempt Face ID now while still on the
        // splash screen. On success the user skips BiometricGateView entirely
        // and lands directly on home. On failure, transition to .appLock for
        // manual retry. Warm transitions use the .warmRelock flow (auto-trigger
        // via BiometricGateView.task), not this path.
        var resolvedDestination = appState.pendingDestination
        if resolvedDestination == .appLock, let authenticate = biometricAuthenticate {
            let success = await authenticate()
            if success {
                SecureLogger.info(
                    "Biometric auth succeeded on splash — routing to .home",
                    category: .auth
                )
                resolvedDestination = .home
            }
            // Failure: resolvedDestination stays .appLock → BiometricGateView
            // shown with manual retry (autoTriggerBiometric=false).
        }

        // Transition splash → destination
        if let destination = resolvedDestination {
            appState.context = appState.pendingContext
            appState.flow = destination
            appState.pendingDestination = nil
            appState.pendingContext = nil
            SecureLogger.info("Splash transition → \(destination.rawValue)", category: .auth)
        }
    }

    // MARK: - Private helpers

    private static func deferToast(after delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
}
