//
//  AppLockManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Security
import SwiftUI
import Combine
import UIKit

// MARK: - Lock State

enum LockState: Equatable {
    case unlocked
    case locked
    case sensitiveChallenge(actionID: String)
}

// MARK: - AppLockConfig

struct AppLockConfig {
    var maxAttempts: Int = 3
    var backgroundTimeout: TimeInterval = 30
    /// Progressive lockout durations per round: 30 s → 5 min → 15 min.
    var lockoutDurations: [TimeInterval] = [30, 300, 600]
    /// After this many lockout rounds the user must log in via OTP.
    var maxRounds: Int = 4

    static let `default` = AppLockConfig()
}

// MARK: - LockoutStorage

protocol LockoutStorage {
    func saveInt(_ value: Int, forKey key: String)
    func readInt(forKey key: String) -> Int
    func saveDouble(_ value: Double, forKey key: String)
    func readDouble(forKey key: String) -> Double
    func delete(forKey key: String)
}

// MARK: - KeychainLockoutStorage (production)

final class KeychainLockoutStorage: LockoutStorage {

    func saveInt(_ value: Int, forKey key: String) {
        withUnsafeBytes(of: Int64(value)) { save(Data($0), forKey: key) }
    }

    func readInt(forKey key: String) -> Int {
        guard let data = load(forKey: key),
              data.count == MemoryLayout<Int64>.size else { return 0 }
        return Int(data.withUnsafeBytes { $0.load(as: Int64.self) })
    }

    func saveDouble(_ value: Double, forKey key: String) {
        withUnsafeBytes(of: value) { save(Data($0), forKey: key) }
    }

    func readDouble(forKey key: String) -> Double {
        guard let data = load(forKey: key),
              data.count == MemoryLayout<Double>.size else { return 0 }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    func delete(forKey key: String) {
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }

    private func save(_ data: Data, forKey key: String) {
        let base: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrAccount as String:    key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(base as CFDictionary)
        var query = base
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
            ? result as? Data
            : nil
    }
}

// MARK: - AppLockClock

protocol AppLockClock {
    func now() -> Date
    func sleep(seconds: Int) async throws
}

// MARK: - SystemClock (production)

final class SystemClock: AppLockClock {
    func now() -> Date { Date() }
    func sleep(seconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
    }
}

// MARK: - AppLockManager

@MainActor
final class AppLockManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var state: LockState = .unlocked
    @Published private(set) var failedAttempts: Int = 0
    /// Which lockout round we are on — increments every time maxAttempts is hit.
    /// Used to compute the progressive lockout duration. Persisted in storage.
    @Published private(set) var lockoutRound: Int = 0
    @Published var lockoutMessage: String? = nil
    @Published var revocationError: String? = nil
    @Published private(set) var requiresPhoneLogin: Bool = false
    // MARK: - Storage Keys

    private enum LockoutKey {
        private static let prefix = AppInfo.bundleIdentifier + ".lockout."
        /// Cumulative failed attempt count for the current lockout window.
        static let attempts = prefix + "attempts"
        /// Unix timestamp (Double) when the current lockout expires.
        /// Set to Date.distantFuture when the user is permanently locked out.
        static let expiry   = prefix + "expiry"
        /// How many lockout rounds have been triggered (determines duration).
        static let round    = prefix + "round"
    }

    // MARK: - Dependencies

    let passcodeManager: PasscodeManaging
    let biometricManager: BiometricManaging

    private let analytics: AnalyticsTracking
    private let storage: LockoutStorage
    private let config: AppLockConfig
    private let clock: AppLockClock

    private var lockoutTask: Task<Void, Never>?
    private var backgroundedAt: Date?
    /// Tracks whether the user was already authenticated when the app last went
    /// to background. Used to prevent auto-unlock when the user backgrounded
    /// while still on the lock screen (partial or no passcode entry).
    private var wasUnlockedWhenBackgrounded: Bool = false
    /// Set to true before intentionally opening a system prompt (e.g. Settings
    /// for permissions). Prevents the lock screen firing on the next foreground
    /// event so the user lands back on the same screen they left.
    private var skipNextLock: Bool = false
    /// Durable version of skipNextLock — set when the user opens the OS Settings
    /// for a permission grant (contacts, camera, etc.). Unlike skipNextLock, this
    /// survives the .inactive scene-phase bounce that happens when Settings opens,
    /// so the flag is still live when the real .active fires on return.
    private var permissionFlowActive: Bool = false
    /// True when a real device lock happened during the current background period
    /// (protected data became unavailable). Distinguishes a device lock (→ biometric
    /// re-auth on return) from a plain app switch (→ seamless resume, no re-auth).
    /// Reset at the start of each background cycle; read and cleared on foreground.
    private var deviceLockedWhileBackgrounded: Bool = false
    /// App-lifecycle notification tokens (background cover + device-lock detection).
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Init (Production)

    init(
        passcodeManager: PasscodeManaging,
        biometricManager: BiometricManaging,
        analytics: AnalyticsTracking? = nil
    ) {
        self.passcodeManager = passcodeManager
        self.biometricManager = biometricManager
        self.analytics = analytics ?? AnalyticsManager.shared
        self.storage = KeychainLockoutStorage()
        self.config = .default
        self.clock = SystemClock()
        restorePersistedState()
        // Lock immediately so the first SwiftUI render never shows the dashboard
        // before the passcode screen — prevents the flash on cold launch and
        // notification tap.
        // Lock immediately so the first SwiftUI render never shows the
        // dashboard before authentication. StartupRouter resets this for
        // paths that don't need the gate.
        if passcodeManager.isPasscodeSet || RSAKeyManager.shared.keysExist() {
            state = .locked
        }
        observeAppLifecycle()
    }

    // MARK: - Init (Testing)

    init(
        passcodeManager: PasscodeManaging,
        biometricManager: BiometricManaging,
        storage: LockoutStorage,
        config: AppLockConfig,
        clock: AppLockClock,
        analytics: AnalyticsTracking? = nil
    ) {
        self.passcodeManager = passcodeManager
        self.biometricManager = biometricManager
        self.analytics = analytics ?? AnalyticsManager.shared
        self.storage = storage
        self.config = config
        self.clock = clock
        restorePersistedState()
        // Lock immediately so the first SwiftUI render never shows the
        // dashboard before authentication. StartupRouter resets this for
        // paths that don't need the gate.
        if passcodeManager.isPasscodeSet || RSAKeyManager.shared.keysExist() {
            state = .locked
        }
    }

    // MARK: - Convenience

    var isPasscodeSet: Bool              { passcodeManager.isPasscodeSet }
    var isBiometricAvailable: Bool       { biometricManager.isAvailable }
    var isBiometricHardwarePresent: Bool { biometricManager.isHardwarePresent }
    var biometricType: BiometricType     { biometricManager.biometricType }
    var hardwareBiometricType: BiometricType { biometricManager.hardwareBiometricType }
    var isBiometricEnabled: Bool         { passcodeManager.isBiometricKeyEnrolled || RSAKeyManager.shared.keysExist() }
    var isBiometricPermissionDenied: Bool { biometricManager.isAppPermissionDenied }
    var maxPasscodeAttempts: Int         { config.maxAttempts }
    /// True when any auth method is enrolled — passcode (legacy) or RSA
    /// biometric (current product model). Drives the lock state machine.
    var hasAuthMethod: Bool {
        isPasscodeSet || RSAKeyManager.shared.keysExist()
    }

    // MARK: - App Lifecycle

    /// Call before programmatically opening a system screen (Settings, permission
    /// dialogs) so the lock screen does not appear when the user returns.
    func suppressLockOnNextForeground() {
        skipNextLock = true
    }

    /// Call before opening OS Settings for a runtime permission grant (contacts,
    /// camera, etc.). Sets both the one-shot flag and the durable flag so the
    /// lock is suppressed even if the scene-phase bounces through .inactive first.
    func notifyWillOpenPermissionSettings() {
        skipNextLock = true
        permissionFlowActive = true
    }

    deinit {
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Observes app lifecycle for two purposes:
    ///
    ///  1. Privacy cover — raises the splash cover synchronously the instant the app
    ///     backgrounds, so the app-switcher snapshot never shows real UI (Apple
    ///     QA1838). Mirrors ScreenSecurityManager's use of didEnterBackground.
    ///  2. Device-lock detection — `protectedDataWillBecomeUnavailable` fires when the
    ///     device locks (with a passcode). Recording it lets the next foreground tell a
    ///     real device lock (→ biometric re-auth) apart from a plain app switch
    ///     (→ seamless resume). This is the Google-Pay-style distinction.
    private func observeAppLifecycle() {
        let center = NotificationCenter.default

        // Delivered on the main thread; assumeIsolated lets us raise the cover
        // synchronously, before the task-switcher snapshot is taken.
        let background = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Start a fresh background cycle.
                self.backgroundedAt = self.clock.now()
                self.wasUnlockedWhenBackgrounded = (self.state == .unlocked)
                self.deviceLockedWhileBackgrounded = false
                // Skip the cover for intentional in-app system prompts (opening
                // Settings for a permission) and trusted full-screen flows (KYC SDK),
                // which manage their own presentation and expect a seamless return.
                guard !self.skipNextLock,
                      !self.permissionFlowActive,
                      !ScreenSecurityManager.shared.isProtectionSuspended else { return }
                SecureWindowShield.shared.show(.auth)
            }
        }

        // Device lock — protected data becomes unavailable when the screen locks on a
        // passcode-protected device. Marks this background cycle as a real lock so the
        // next foreground triggers biometric re-auth.
        let deviceLock = center.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.deviceLockedWhileBackgrounded = true }
        }

        lifecycleObservers = [background, deviceLock]
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Cover + bookkeeping are handled synchronously in the didEnterBackground
            // observer (observeAppLifecycle) so the app-switcher snapshot is protected
            // before it is captured. Nothing to do here.
            break
        case .active:
            let suppress = skipNextLock || permissionFlowActive
            skipNextLock = false
            permissionFlowActive = false

            let wasLocked = deviceLockedWhileBackgrounded
            let since = backgroundedAt
            backgroundedAt = nil
            deviceLockedWhileBackgrounded = false

            if suppress {
                SecureWindowShield.shared.hide(.auth)
                return
            }

            // A pure .inactive → .active bounce never fires didEnterBackground, so
            // `since` is nil. This happens for in-process system overlays — the Face ID
            // prompt, Control Center, permission alerts — none of which are a real
            // backgrounding and none of which should re-lock. Resume seamlessly.
            // Without this, the biometric gate's OWN Face ID prompt would relock the
            // app and bounce the user from the retry screen to the warm-relock splash.
            // Real backgrounding (app switch, device lock) always sets `backgroundedAt`.
            guard since != nil else {
                SecureWindowShield.shared.hide(.auth)
                return
            }

            // Only enforce for users past the dashboard. Mid-onboarding is governed
            // by RootView's 10-minute timeout. Take the cover down either way.
            guard UserDefaults.standard.bool(forKey: "kycCompleted") else {
                SecureWindowShield.shared.hide(.auth)
                return
            }

            if hasAuthMethod {
                // Google-Pay model: biometric re-auth ONLY when the device was actually
                // locked (or we were already sitting on the lock screen). A plain app
                // switch resumes seamlessly no matter how long it lasted.
                let needsReauth = wasLocked || !wasUnlockedWhenBackgrounded
                if needsReauth {
                    if state == .locked {
                        // Already on the biometric gate (e.g. a prior failed retry).
                        // The gate owns the screen — reveal it so the user can retry.
                        SecureWindowShield.shared.hide(.auth)
                    } else {
                        // RootView's lockManager.state observer routes .locked →
                        // .warmRelock (auto-triggers Face ID). The gate takes the cover
                        // down when its attempt finishes; the cover stays up until then.
                        state = .locked
                    }
                } else {
                    // Plain app switch — seamless resume, no re-auth.
                    SecureWindowShield.shared.hide(.auth)
                }
            } else {
                // No biometric enrolled. There is no in-app challenge to present, so
                // resume seamlessly — but preserve the server-idle safety net: if the
                // server session is certainly dead, force phone re-auth.
                SecureWindowShield.shared.hide(.auth)
                let elapsed = since.map { clock.now().timeIntervalSince($0) } ?? 0
                if elapsed >= AppState.apiIdleTimeout {
                    SecureLogger.info(
                        "Background \(Int(elapsed))s, no biometric → ChoiceScreen",
                        category: .auth
                    )
                    NotificationCenter.default.post(
                        name: .sessionExpired,
                        object: nil,
                        userInfo: ["message": "Your session has expired. Please sign in again."]
                    )
                }
            }
        default:
            break
        }
    }

    /// Immediately locks the app. Currently has no call sites.
    /// If you add one (e.g. remote-kill or fraud-triggered lockout), revisit the
    /// short-background resume assumption in handleScenePhase(.active) — it relies
    /// on nothing transitioning state to .locked between .background and .active.
    func lock() {
        guard hasAuthMethod else { return }
        state = .locked
    }

    func resetToUnlocked() {
        state = .unlocked
    }

    func evaluateOnLaunch() {
        if isPasscodeSet {
            state = .locked
        }
    }

    // MARK: - Unlock with Passcode

    func unlockWithPasscode(_ pin: String) async -> Bool {
        guard !isLockedOut else { return false }

        do {
            let ok = try passcodeManager.verifyPasscode(pin)
            if ok {
                resetFailures()
                transitionToUnlocked()
                analytics.log(AnalyticsEvent.biometricAuth, params: [
                    AnalyticsParam.method: "passcode",
                    AnalyticsParam.reason: "unlock_success"
                ])
                return true
            } else {
                recordFailure()
                analytics.log(AnalyticsEvent.suspiciousActivity, params: [
                    AnalyticsParam.reason: "wrong_passcode",
                    AnalyticsParam.count: failedAttempts
                ])
                return false
            }
        } catch PasscodeError.notSet {
            transitionToUnlocked()
            return true
        } catch PasscodeError.migrationRequired {
            resetFailures()
            transitionToUnlocked()
            lockoutMessage = "Security upgrade required. Please set a new passcode."
            return true
        } catch {
            lockoutMessage = "Unable to verify passcode. Please restart the app."
            return false
        }
    }

    // MARK: - Unlock with Biometric

    func unlockWithBiometric() async {
        guard isBiometricAvailable, isBiometricEnabled else { return }
        do {
            try await biometricManager.evaluate(reason: "Unlock MovoCash")
            resetFailures()
            transitionToUnlocked()
            analytics.log(AnalyticsEvent.biometricAuth, params: [
                AnalyticsParam.method: "biometric",
                AnalyticsParam.reason: "unlock_success"
            ])
        } catch let err as BiometricError {
            analytics.log(AnalyticsEvent.suspiciousActivity, params: [
                AnalyticsParam.reason: "biometric_failed",
                AnalyticsParam.errorCode: err.localizedDescription
            ])
            if err.shouldFallbackToPasscode {
                if case .lockout = err {
                    lockoutMessage = err.errorDescription
                }
            }
        } catch {
            // unknown — stay locked
        }
    }

    // MARK: - Silent Unlock (after RSA server auth)

    /// Unlocks the app after a successful RSA biometric server authentication.
    /// The biometric was already verified via RSA key signing — no second prompt needed.
    func unlockAfterRSAAuth() {
        guard state == .locked else { return }
        resetFailures()
        transitionToUnlocked()
    }

    // MARK: - Passcode Setup

    func setupPasscode(_ pin: String) async throws {
        try passcodeManager.setPasscode(pin)
        analytics.log(AnalyticsEvent.pinChanged, params: [AnalyticsParam.type: "setup"])
    }

    func changePasscode(old: String, new: String) async throws {
        let ok = try passcodeManager.verifyPasscode(old)
        guard ok else { throw AppLockError.wrongPasscode }
        try passcodeManager.setPasscode(new)
        analytics.log(AnalyticsEvent.pinChanged, params: [AnalyticsParam.type: "change"])
    }

    func removePasscode(confirmedWith pin: String) async throws {
        let ok = try passcodeManager.verifyPasscode(pin)
        guard ok else { throw AppLockError.wrongPasscode }
        try passcodeManager.clearAll()
        state = .unlocked
    }

    // MARK: - Biometric Enrollment

    func enrollBiometrics() throws {
        try passcodeManager.enrollBiometricKey()
        analytics.log(AnalyticsEvent.biometricEnrolled)
    }

    func revokeBiometrics() throws {
        try passcodeManager.clearBiometricKey()
        RSAKeyManager.shared.deleteKeyPair()
        analytics.log(AnalyticsEvent.biometricRevoked)
    }

    func revokeBiometricSafely() {
        do {
            try revokeBiometrics()
        } catch {
            showTemporaryError(error.localizedDescription)
        }
    }

    func showTemporaryError(_ message: String) {
        revocationError = message
        Task {
            try? await clock.sleep(seconds: 3)
            revocationError = nil
        }
    }

    // MARK: - Sensitive Action Challenge

    func requestSensitiveChallenge(actionID: String) {
        guard isPasscodeSet else { return }
        state = .sensitiveChallenge(actionID: actionID)
    }

    func cancelSensitiveChallenge() {
        if case .sensitiveChallenge = state {
            state = .unlocked
        }
    }

    // MARK: - Logout

    func logout() {
        lockoutTask?.cancel()
        lockoutTask = nil
        // Keep the biometric enrollment sentinel (Secure Enclave bio.key) across
        // logout, mirroring how the RSA key pair is intentionally retained (see
        // SessionManager.resetAppState). This keeps the Profile Face ID toggle ON
        // after a biometric re-login, which routes straight to Home and never goes
        // through BiometricEnrollView (the only path that recreates the sentinel).
        // The sentinel is still removed on explicit disable (revokeBiometrics) or
        // re-enrollment (enrollBiometricKey clears + recreates it).
        try? passcodeManager.clearPasscode()
        failedAttempts         = 0
        lockoutRound           = 0
        lockoutMessage         = nil
        requiresPhoneLogin     = false
        state                  = .unlocked
        clearAllLockoutState()
    }

    // MARK: - Private Helpers

    private var isLockedOut: Bool { lockoutTask != nil }

    private func transitionToUnlocked() {
        state = .unlocked
        // Authentication succeeded — reveal the (now authenticated) screen.
        SecureWindowShield.shared.hide(.auth)
    }

    private func recordFailure() {
        failedAttempts += 1
        // Persist immediately — survives force-quit between attempts.
        storage.saveInt(failedAttempts, forKey: LockoutKey.attempts)
        if failedAttempts >= config.maxAttempts {
            startLockout()
        }
    }

    private func resetFailures() {
        failedAttempts    = 0
        lockoutRound      = 0
        lockoutMessage    = nil
        requiresPhoneLogin = false
        clearAllLockoutState()
    }

    // MARK: - Progressive Lockout

    private func startLockout() {
        lockoutRound += 1
        storage.saveInt(lockoutRound,   forKey: LockoutKey.round)
        storage.saveInt(failedAttempts, forKey: LockoutKey.attempts)

        // All rounds exhausted — permanent lockout until OTP login.
        guard lockoutRound < config.maxRounds else {
            lockoutMessage = "Too many failed attempts. Please log in with your phone number."
            requiresPhoneLogin = true
            storage.saveDouble(
                Date.distantFuture.timeIntervalSince1970,
                forKey: LockoutKey.expiry
            )
            analytics.log(AnalyticsEvent.lockoutPermanent, params: [
                AnalyticsParam.lockoutRound: lockoutRound
            ])
            return
        }

        // Pick the duration for this round, capped at the last defined entry.
        let durationIndex = min(lockoutRound - 1, config.lockoutDurations.count - 1)
        let duration      = config.lockoutDurations[durationIndex]
        let expiry        = clock.now().addingTimeInterval(duration)

        storage.saveDouble(expiry.timeIntervalSince1970, forKey: LockoutKey.expiry)
        analytics.log(AnalyticsEvent.lockoutTriggered, params: [
            AnalyticsParam.lockoutRound: lockoutRound,
            AnalyticsParam.lockoutDuration: Int(duration)
        ])
        startCountdown(seconds: Int(duration))
    }

    /// Shared countdown used both for new lockouts and for restored lockouts
    /// (when the user re-opens the app while a lockout is still active).
    private func startCountdown(seconds: Int) {
        lockoutMessage = "Too many attempts. Try again in \(formatDuration(seconds))."

        lockoutTask = Task {
            do {
                for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                    try await clock.sleep(seconds: 1)
                    if remaining == 0 {
                        failedAttempts = 0
                        lockoutMessage = nil
                        lockoutTask    = nil
                        clearLockoutExpiry()
                        storage.saveInt(0, forKey: LockoutKey.attempts)
                    } else {
                        lockoutMessage = "Too many attempts. Try again in \(formatDuration(remaining))."
                    }
                }
            } catch {
                // Task cancelled — e.g. on logout. Caller handles cleanup.
            }
        }
    }

    /// Called from init to restore any lockout state that was active when the
    /// app was last killed. Prevents resetting the counter via force-quit.
    private func restorePersistedState() {
        lockoutRound   = storage.readInt(forKey: LockoutKey.round)
        failedAttempts = storage.readInt(forKey: LockoutKey.attempts)

        let expiryTimestamp = storage.readDouble(forKey: LockoutKey.expiry)
        guard expiryTimestamp > 0 else { return }

        // Permanent lockout — show message without starting a countdown.
        if lockoutRound >= config.maxRounds {
            lockoutMessage = "Too many failed attempts. Please log in with your phone number."
            requiresPhoneLogin = true
            return
        }

        let remaining = Date(timeIntervalSince1970: expiryTimestamp).timeIntervalSince(clock.now())

        if remaining > 0 {
            // Lockout is still active — resume the countdown from where it left off.
            startCountdown(seconds: Int(remaining.rounded(.up)))
        } else {
            // Lockout expired while the app was closed.
            // Clear the expiry but keep lockoutRound so the next failure
            // triggers the next (longer) duration.
            failedAttempts = 0
            storage.saveInt(0, forKey: LockoutKey.attempts)
            clearLockoutExpiry()
        }
    }

    private func clearLockoutExpiry() {
        storage.delete(forKey: LockoutKey.expiry)
    }

    private func clearAllLockoutState() {
        storage.delete(forKey: LockoutKey.attempts)
        storage.delete(forKey: LockoutKey.expiry)
        storage.delete(forKey: LockoutKey.round)
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)s" }
        let minutes = (seconds + 59) / 60
        return "\(minutes) min"
    }
}

// MARK: - Errors

enum AppLockError: LocalizedError {
    case wrongPasscode
    var errorDescription: String? { "Incorrect passcode" }
}

