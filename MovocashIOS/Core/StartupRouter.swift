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
    
    private static let splashBiometricTimeout: TimeInterval = 8
    
    // MARK: - Synchronous bootstrap (called from @main App.init)
    
    static func bootstrap(
        appState: AppState,
        keychain: KeychainManagerProtocol,
        lockManager: AppLockManager
    ) {
        UserDefaults.standard.removeObject(forKey: "kycInProgress")
        
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
            
            // Secure default for every other mid-onboarding cold launch (manual kill,
            // memory termination, etc.): start fresh at Choice with tokens cleared.
            SecureLogger.info("Boot route → .choice (mid-onboarding, restart)", category: .auth)
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
        appConfigService: AppConfigServiceProtocol? = nil,
        configure: (() async throws -> Void)? = nil,
        biometricAuthenticate: (() async -> Bool)? = nil
    ) async {
        guard !appState.hasCompletedBootstrap else { return }
        appState.hasCompletedBootstrap = true

        let start = Date()

        if let appConfigService {
            appState.appUpdate = await appConfigService.fetchUpdateOutcome()
        }
        
        // MoVO session config — fetches the movo-info signing key. This must complete
        // before any other API call (login, biometric, KYC), so it runs first while the
        // splash is still showing. Bounded retries cover transient failures; if it still
        // fails the app proceeds rather than blocking launch indefinitely.
        if let configure {
            for attempt in 1...3 {
                do {
                    try await configure()
                    SecureLogger.info("MoVO session config loaded", category: .auth)
                    break
                } catch {
                    SecureLogger.error(
                        "MoVO session config attempt \(attempt) failed: \(error.localizedDescription)",
                        category: .auth
                    )
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                    }
                }
            }
        }
        
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
        
        var resolvedDestination = appState.pendingDestination
        if appState.appUpdate.isBlocking {
            SecureLogger.info(
                "Skipping splash biometric — blocking app update gate is active",
                category: .auth
            )
        } else if resolvedDestination == .appLock, let authenticate = biometricAuthenticate {
            let success = await raceAgainstTimeout(
                seconds: splashBiometricTimeout,
                operation: authenticate
            )
            if success {
                SecureLogger.info(
                    "Biometric auth succeeded on splash — routing to .home",
                    category: .auth
                )
                resolvedDestination = .home
            } else {
                SecureLogger.info(
                    "Biometric auth unresolved or failed within \(Int(splashBiometricTimeout))s — routing to .appLock for manual retry",
                    category: .auth
                )
            }
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
    
    private static func raceAgainstTimeout(
        seconds: TimeInterval,
        operation: @escaping () async -> Bool
    ) async -> Bool {
        let stream = AsyncStream<Bool> { continuation in
            // Producer 1 — the real work. Intentionally not retained: on timeout it
            // keeps running detached and its late yield is dropped.
            Task {
                let result = await operation()
                continuation.yield(result)
                continuation.finish()
            }
            // Producer 2 — the timeout.
            let timeout = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                continuation.yield(false)
                continuation.finish()
            }
            // Stop only the timer when the stream ends; never cancel the work task.
            continuation.onTermination = { _ in timeout.cancel() }
        }
        
        for await first in stream {
            return first
        }
        return false
    }
    
    private static func deferToast(after delay: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            block()
        }
    }
}
