//
//  BiometricManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import LocalAuthentication
import Foundation

// MARK: - Types

enum BiometricType {
    case faceID
    case touchID
    case none

    var displayName: String {
        switch self {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .none:    return "Biometrics"
        }
    }

    var systemImageName: String {
        switch self {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .none:    return "lock.fill"
        }
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case userCancel
    case userFallback          // user tapped "Enter Passcode"
    case systemCancel
    case authFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:  return "Biometric authentication is not available"
        case .notEnrolled:   return "No biometric data is enrolled on this device"
        case .lockout:       return "Biometrics are locked. Please use your passcode."
        case .userCancel:    return "Authentication was cancelled"
        case .userFallback:  return "Use passcode instead"
        case .systemCancel:  return "Authentication was cancelled by the system"
        case .authFailed:    return "Authentication failed"
        case .unknown(let e): return e.localizedDescription
        }
    }

    /// True when the caller should fall back to PIN
    var shouldFallbackToPasscode: Bool {
        switch self {
        case .userFallback, .lockout, .notAvailable, .notEnrolled: return true
        default: return false
        }
    }
}

// MARK: - Protocol (enables mocking in tests)

protocol BiometricManaging {
    var biometricType: BiometricType { get }
    var isAvailable: Bool { get }
    func evaluate(reason: String) async throws
}

// MARK: - Implementation

final class BiometricManager: BiometricManaging, Sendable {

    // MARK: - Availability

    var biometricType: BiometricType {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch ctx.biometryType {
        case .faceID:             return .faceID
        case .touchID:            return .touchID
        case .none:               return .none
        default:
            // .opticID introduced in iOS 17 (Vision Pro) — treat as faceID
            if #available(iOS 17.0, *), ctx.biometryType == .opticID {
                return .faceID
            }
            return .none
        }
    }

    var isAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // MARK: - Evaluate

    /// Throws `BiometricError` on failure. Returns normally on success.
    func evaluate(reason: String) async throws {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Passcode"   // shown below biometric prompt
        ctx.localizedCancelTitle   = "Cancel"

        do {
            let success = try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw BiometricError.authFailed
            }
            // MERGE: fire analytics event here if needed
        } catch let laError as LAError {
            throw map(laError)
        } catch {
            throw BiometricError.unknown(error)
        }
    }

    // MARK: - LAError mapping

    private func map(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:           return .notAvailable
        case .biometryNotEnrolled:            return .notEnrolled
        case .biometryLockout:                return .lockout
        case .userCancel:                     return .userCancel
        case .userFallback:                   return .userFallback
        case .systemCancel, .appCancel:       return .systemCancel
        case .authenticationFailed:           return .authFailed
        default:                              return .unknown(error)
        }
    }
}
