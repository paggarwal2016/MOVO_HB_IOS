//
//  AppLockManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Security
import SwiftUI
import Combine

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
        if passcodeManager.isPasscodeSet {
            state = .locked
        }
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
        if passcodeManager.isPasscodeSet {
            state = .locked
        }
    }

    // MARK: - Convenience

    var isPasscodeSet: Bool              { passcodeManager.isPasscodeSet }
    var isBiometricAvailable: Bool       { biometricManager.isAvailable }
    var isBiometricHardwarePresent: Bool { biometricManager.isHardwarePresent }
    var biometricType: BiometricType     { biometricManager.biometricType }
    var hardwareBiometricType: BiometricType { biometricManager.hardwareBiometricType }
    var isBiometricEnabled: Bool         { passcodeManager.isBiometricKeyEnrolled }
    var isBiometricPermissionDenied: Bool { biometricManager.isAppPermissionDenied }
    var maxPasscodeAttempts: Int         { config.maxAttempts }

    // MARK: - App Lifecycle

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = clock.now()
            wasUnlockedWhenBackgrounded = (state == .unlocked)
        case .active:
            guard let since = backgroundedAt else { return }
            backgroundedAt = nil
            let elapsed = clock.now().timeIntervalSince(since)
            guard isPasscodeSet else { return }
            // Always lock on return from background so the dashboard never
            // flashes before authentication is confirmed.
            state = .locked
            if elapsed < config.backgroundTimeout && wasUnlockedWhenBackgrounded {
                // Short background and the user was already authenticated —
                // resume seamlessly without asking for the passcode again.
                state = .unlocked
            } else if elapsed >= config.backgroundTimeout {
                // Long background — trigger biometric (falls back to passcode).
                Task { await unlockWithBiometric() }
            }
            // If the user was on the lock screen when they backgrounded
            // (wasUnlockedWhenBackgrounded == false), we stay locked regardless
            // of elapsed time — they must complete the full passcode entry.
        default:
            break
        }
    }

    func lock() {
        guard isPasscodeSet else { return }
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
        try? passcodeManager.clearAll()
        failedAttempts    = 0
        lockoutRound      = 0
        lockoutMessage    = nil
        requiresPhoneLogin = false
        state             = .unlocked
        clearAllLockoutState()
    }

    // MARK: - Private Helpers

    private var isLockedOut: Bool { lockoutTask != nil }

    private func transitionToUnlocked() {
        state = .unlocked
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

