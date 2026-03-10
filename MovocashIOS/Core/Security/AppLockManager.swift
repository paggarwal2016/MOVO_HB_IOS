//
//  AppLockManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import SwiftUI
import Combine

// MARK: - Lock State

enum LockState: Equatable {
    case unlocked
    case locked
    case sensitiveChallenge(actionID: String)
}

// MARK: - AppLockManager

@MainActor
final class AppLockManager: ObservableObject {

    // MARK: Published

    @Published private(set) var state: LockState = .unlocked
    @Published private(set) var failedAttempts: Int = 0
    @Published var lockoutMessage: String? = nil

    // MARK: Config

    private enum Config {
        static let maxAttempts       = 5
        static let lockoutSeconds    = 30
        static let backgroundTimeout: TimeInterval = 30  // lock after 30 s in background
    }

    // MARK: Dependencies

    let passcodeManager: PasscodeManaging
    let biometricManager: BiometricManaging

    // Lockout timer
    private var lockoutTask: Task<Void, Never>?
    // Background timer
    private var backgroundedAt: Date?

    // MARK: Init

    init(
        passcodeManager: PasscodeManaging,
        biometricManager: BiometricManaging
    ) {
        self.passcodeManager = passcodeManager
        self.biometricManager = biometricManager
    }

    // MARK: - Convenience

    var isPasscodeSet: Bool        { passcodeManager.isPasscodeSet }
    var isBiometricAvailable: Bool { biometricManager.isAvailable }
    var biometricType: BiometricType { biometricManager.biometricType }

    // isBiometricKeyEnrolled means the user opted-in during onboarding
    var isBiometricEnabled: Bool   { passcodeManager.isBiometricKeyEnrolled }

    // MARK: - App lifecycle

    /// Call from `.onChange(of: scenePhase)` in your App entry point.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = Date()
        case .active:
            guard let since = backgroundedAt else { return }
            backgroundedAt = nil
            let elapsed = Date().timeIntervalSince(since)
            guard elapsed >= Config.backgroundTimeout, isPasscodeSet else { return }
            lock()
            // App came back from background — trigger biometric immediately
            Task { await unlockWithBiometric() }
        default:
            break
        }
    }

    /// Lock immediately (e.g. on logout, or first foreground after install).
    func lock() {
        guard isPasscodeSet else { return }
        state = .locked
    }

    /// Call once after session restore to decide whether to lock.
    func evaluateOnLaunch() {
        if isPasscodeSet {
            state = .locked
        }
    }

    // MARK: - Unlock with passcode

    /// Returns `true` on success. Manages attempt counter + lockout.
    func unlockWithPasscode(_ pin: String) async -> Bool {
        guard !isLockedOut else { return false }

        do {
            let ok = try passcodeManager.verifyPasscode(pin)
            if ok {
                resetFailures()
                transitionToUnlocked()
                return true
            } else {
                recordFailure()
                return false
            }
        } catch {
            // passcode not set — shouldn't reach here in normal flow
            transitionToUnlocked()
            return true
        }
    }

    // MARK: - Unlock with biometric

    func unlockWithBiometric() async {
        guard isBiometricAvailable, isBiometricEnabled else { return }
        do {
            try await biometricManager.evaluate(reason: "Unlock MovoCash")
            resetFailures()
            transitionToUnlocked()
        } catch let err as BiometricError {
            if err.shouldFallbackToPasscode {
                // Stay on lock screen — PIN pad is already visible
                if case .lockout = err {
                    lockoutMessage = err.errorDescription
                }
            }
            // userCancel / systemCancel: do nothing, user stays on lock screen
        } catch {
            // unknown — stay locked
        }
    }

    // MARK: - Passcode setup

    func setupPasscode(_ pin: String) async throws {
        try passcodeManager.setPasscode(pin)
        // After setup we remain in whatever state the caller set
    }

    func changePasscode(old: String, new: String) async throws {
        let ok = try passcodeManager.verifyPasscode(old)
        guard ok else { throw AppLockError.wrongPasscode }
        try passcodeManager.setPasscode(new)
    }

    func removePasscode(confirmedWith pin: String) async throws {
        let ok = try passcodeManager.verifyPasscode(pin)
        guard ok else { throw AppLockError.wrongPasscode }
        try passcodeManager.clearAll()
        state = .unlocked
    }

    // MARK: - Biometric enrollment

    func enrollBiometrics() throws {
        try passcodeManager.enrollBiometricKey()
    }

    func revokeBiometrics() throws {
        try passcodeManager.clearBiometricKey()
    }

    // MARK: - Sensitive action challenge

    func requestSensitiveChallenge(actionID: String) {
        guard isPasscodeSet else { return }   // no lock → fire directly
        state = .sensitiveChallenge(actionID: actionID)
    }

    func cancelSensitiveChallenge() {
        if case .sensitiveChallenge = state {
            state = .unlocked
        }
    }

    // MARK: - Private helpers

    private var isLockedOut: Bool { lockoutTask != nil }

    private func transitionToUnlocked() {
        state = .unlocked
    }

    private func recordFailure() {
        failedAttempts += 1
        if failedAttempts >= Config.maxAttempts {
            startLockout()
        }
    }

    private func resetFailures() {
        failedAttempts = 0
        lockoutMessage = nil
    }

    private func startLockout() {
        let secs = Config.lockoutSeconds
        lockoutMessage = "Too many attempts. Try again in \(secs)s."
        lockoutTask = Task {
            for remaining in stride(from: secs - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if remaining == 0 {
                    failedAttempts = 0
                    lockoutMessage = nil
                    lockoutTask = nil
                } else {
                    lockoutMessage = "Too many attempts. Try again in \(remaining)s."
                }
            }
        }
    }
    
    // MARK: - TODO: Future Implementation will check this logic
    func logout() {
        // Cancel any running lockout countdown
        lockoutTask?.cancel()
        lockoutTask = nil
        
        // Wipe keychain entries (passcode hash, salt, SE key)
        try? passcodeManager.clearAll()
        
        // Reset published state
        failedAttempts  = 0
        lockoutMessage  = nil
        state           = .unlocked
    }
}

// MARK: - Errors

enum AppLockError: LocalizedError {
    case wrongPasscode
    var errorDescription: String? { "Incorrect passcode" }
}
