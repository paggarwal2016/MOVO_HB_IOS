//
//  AnalyticsManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/04/26.
//

import Foundation
import CryptoKit
import FirebaseAnalytics

// MARK: - Protocol

protocol AnalyticsTracking {
    // Core
    func log(_ event: String, params: [String: Any]?)
    func setUserProperty(_ value: String, for key: String)
    func trackScreen(_ name: String)

    // Identity
    func identifyUser(from token: String)
    func reapplyIdentity()
    func clearIdentity()

    // Auth
    func trackLoginAttempt(method: AuthMethod)
    func trackLogin(method: AuthMethod)
    func trackLoginFailed(method: AuthMethod, errorCode: String)
    func trackLogout()
    func trackSessionExpired()

    // KYC
    func trackKYCStarted()
    func trackKYCCompleted(step: KYCStep)
    func trackKYCAbandoned(step: KYCStep)
}

extension AnalyticsTracking {
    /// Convenience: forwards to the two-arg requirement so it dynamic-dispatches
    /// to the real implementation instead of a no-op default.
    func log(_ event: String) { log(event, params: nil) }
}


// MARK: - JWT Helper

private enum JWTHelper {
    /// Extracts `payload.userId` as a stable user identifier.
    /// userId is stable across all token refreshes for the same user.
    static func extractSub(from token: String) -> String? {
        guard
            let json    = JWTDecoder.decodePayload(token),
            let payload = json["payload"] as? [String: Any],
            let userId  = payload["userId"] as? Int
        else { return nil }

        return String(userId)
    }
}

// MARK: - String SHA256

private extension String {
    var sha256Hashed: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Analytics Manager

@MainActor
final class AnalyticsManager: AnalyticsTracking {
    static let shared = AnalyticsManager()
    private let keychain: KeychainManagerProtocol = KeychainManager.shared
    private let linkedSubKey   = "analytics_linked_sub"
    private init() {}

    // MARK: - Identity

    /// Call after every login or re-login.
    /// Extracts JWT sub → hashes it → stores in Keychain → sets Firebase UserID.
    /// Same sub on any device always produces the same stable ID.
    func identifyUser(from token: String) {
        _ = Task {
            guard let sub = JWTHelper.extractSub(from: token) else {
                await setAnonymousIdentity()
                return
            }

            // Previous PII-safe implementation (SHA-256 hashed, device-anchored stable ID).
            /*
            let hashedSub = sub.sha256Hashed

            // If this sub is already linked, reuse the stored stable ID
            if let existingSub = try? await keychain.get(linkedSubKey, biometricPrompt: nil),
               existingSub == hashedSub,
               let stableId = try? await keychain.get(analyticsIdKey, biometricPrompt: nil) {
                Analytics.setUserID(stableId)
                return
            }

            // New user on this device — generate once, store forever
            let stableId = await DeviceManager.shared.deviceID().sha256Hashed
            try? await keychain.save(stableId, for: analyticsIdKey, protection: .backgroundSafe)
            try? await keychain.save(hashedSub, for: linkedSubKey, protection: .backgroundSafe)
            Analytics.setUserID(stableId)
            */

            // Set the raw user id as the Firebase UserID.
            Analytics.setUserID(sub)
        }
    }

    /// Call after every silent token refresh — re-applies the same stored ID.
    /// Firebase identity is unchanged even though token rotated.
    func reapplyIdentity() {
        _ = Task {
            // Read the raw user id directly from the stored access token so the
            // Firebase UserID (which must be re-set each launch) stays consistent
            // with identifyUser(from:).
            guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
                  let sub = JWTHelper.extractSub(from: token) else {
                await setAnonymousIdentity()
                return
            }

            // Previous PII-safe implementation (hashed, device-anchored stable ID).
            /*
            guard let stableId = try? await keychain.get(analyticsIdKey, biometricPrompt: nil) else {
                await setAnonymousIdentity()
                return
            }
            Analytics.setUserID(stableId)
            */

            Analytics.setUserID(sub)
            log(AnalyticsEvent.tokenRefreshed, params: [AnalyticsParam.reason: "silent_refresh"])
        }
    }

    /// Call on explicit logout only.
    func clearIdentity() {
        _ = Task {
            try? await keychain.delete(linkedSubKey)
            // Keep device anchor for next anonymous session
            await setAnonymousIdentity()
        }
        setUserProperty(AuthStatusValue.loggedOut, for: UserPropertyKey.authStatus)
    }

    // MARK: - Anonymous (pre-login)

    private func setAnonymousIdentity() async {
        // No authenticated user (pre-login / after logout): clear the Firebase
        // UserID so events aren't attributed to any account. Firebase continues
        // anonymous tracking via its own app-instance ID.
        Analytics.setUserID(nil)
    }

    // MARK: - Core

    func log(_ event: String, params: [String: Any]?) {
        Analytics.logEvent(event, parameters: params.map(Self.sanitize))
    }

    /// Firebase silently drops string parameter values longer than 100 characters.
    /// Truncate them so long values (e.g. localized error text) survive as a usable
    /// prefix instead of being discarded.
    private static func sanitize(_ params: [String: Any]) -> [String: Any] {
        params.mapValues { value in
            guard let string = value as? String, string.count > 100 else { return value }
            return String(string.prefix(100))
        }
    }

    func setUserProperty(_ value: String, for key: String) {
        Analytics.setUserProperty(value, forName: key)
    }

    // MARK: - Screen

    func trackScreen(_ name: String) {
        log(AnalyticsEvent.screenView, params: [AnalyticsParam.screenName: name])
    }

    // MARK: - Auth

    func trackLoginAttempt(method: AuthMethod) {
        log(AnalyticsEvent.loginAttempt, params: [AnalyticsParam.method: method.rawValue])
    }

    func trackLogin(method: AuthMethod) {
        log(AnalyticsEvent.loginSuccess, params: [AnalyticsParam.method: method.rawValue])
        setUserProperty(AuthStatusValue.loggedIn, for: UserPropertyKey.authStatus)
    }

    func trackLoginFailed(method: AuthMethod, errorCode: String) {
        log(AnalyticsEvent.loginFailed, params: [
            AnalyticsParam.method: method.rawValue,
            AnalyticsParam.errorCode: errorCode
        ])
    }

    func trackLogout() {
        log(AnalyticsEvent.logout)
        setUserProperty(AuthStatusValue.loggedOut, for: UserPropertyKey.authStatus)
    }

    func trackSessionExpired() {
        log(AnalyticsEvent.sessionExpired, params: [AnalyticsParam.reason: "token_expired"])
    }

    // MARK: - KYC

    func trackKYCStarted() {
        log(AnalyticsEvent.kycStarted)
    }

    func trackKYCCompleted(step: KYCStep) {
        log(AnalyticsEvent.kycCompleted, params: [AnalyticsParam.kycStep: step.rawValue])
    }

    func trackKYCAbandoned(step: KYCStep) {
        log(AnalyticsEvent.kycAbandoned, params: [AnalyticsParam.step: step.rawValue])
    }
}
