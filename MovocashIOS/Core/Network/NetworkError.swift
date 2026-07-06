//
//  NetworkError.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import Foundation

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
    static let dashboardShouldRefresh = Notification.Name("dashboardShouldRefresh")
    /// Collapse the entire presented/navigation stack back to the dashboard in a
    /// single transition. Observed by RootView (root swap), HomeTabBarView (tab),
    /// DashboardView and ManageExternalAccountsView (reset their nav pushes).
    static let returnToDashboard = Notification.Name("returnToDashboard")
    /// Broadcast when the device is flagged as jailbroken/compromised (e.g. the
    /// network layer rejecting a call). Observed by RootView to raise the app-wide
    /// hard block. See `DeviceIntegrityNotifier`.
    static let deviceCompromised = Notification.Name("deviceCompromised")
}

// MARK: - Device Integrity Broadcast

/// Central, main-actor broadcaster for the compromised-device signal. Any layer
/// that detects a jailbreak (e.g. `NetworkService` rejecting an outbound call)
/// posts through here so the SwiftUI gate in `RootView` can raise on the main
/// actor without cross-thread `@State` mutation.
enum DeviceIntegrityNotifier {
    @MainActor static func broadcastCompromised() {
        NotificationCenter.default.post(name: .deviceCompromised, object: nil)
    }
}

enum NetworkError: LocalizedError, Sendable {

    case invalidResponse
    case unauthorized
    case decodingError
    case serverMessage(String)
    case apiError(Int)
    case rateLimited
    case serverError
    case noInternet
    case timeout
    case requestFailed(String)
    case securityViolation
    case secureConnectionFailed
    case invalidURL
    case encodingError
    case noContent
    case deviceSessionExpired(message: String?)
    case unknown

    var errorDescription: String? {
        switch self {

        case .invalidResponse:
            return "Invalid server response"

        case .unauthorized:
            return "Session expired. Please login again."

        case .decodingError:
            return "Unable to process server data"

        case .serverMessage(let msg):
            return msg

        case .apiError(let code):
            return "Request failed with status code \(code)"

        case .rateLimited:
            return "Too many requests. Please try again later."

        case .serverError:
            return "Server is currently unavailable. Please try again."

        case .noInternet:
            return "No internet connection"

        case .timeout:
            return "The request timed out. Please try again."

        case .requestFailed(let reason):
            return "Request failed: \(reason)"

        case .securityViolation:
            return "For your security, this action is blocked on this device."

        case .secureConnectionFailed:
            return "We couldn't establish a secure connection. Please check your network and try again."

        case .invalidURL:
            return "Invalid URL"

        case .encodingError:
            return "Failed to encode request data"

        case .noContent:
            return nil

        case .deviceSessionExpired(let message):
            // Surface only the server's exact message — no canned default.
            return message

        case .unknown:
            return "Something went wrong"
        }
    }
}

extension Error {
    /// Session expiry and intentional logout are handled centrally; callers must not
    /// surface duplicate toasts for these errors.
    var shouldShowUserFacingToast: Bool {
        if self is CancellationError { return false }
        if let error = self as? NetworkError, case .unauthorized = error { return false }
        return true
    }
}

// MARK: - Session Expiry Detection

/// Central detection and broadcast for server-driven session termination.
enum SessionExpiryNotifier {

    /// Response parsing only — safe to call from `NetworkService`'s nonisolated request path.
    nonisolated static func shouldTerminateSession(statusCode: Int, data: Data) -> Bool {
        if statusCode == 401 { return true }
        // Literal — avoids module-level storage that Swift 6 may isolate to @MainActor.
        guard [403, 419, 440].contains(statusCode),
              let message = apiMessage(from: data) else { return false }
        return isSessionExpiredMessage(message)
    }

    nonisolated static func displayMessage(statusCode: Int, data: Data) -> String {
        if let message = apiMessage(from: data), !message.isEmpty {
            return message
        }
        return "Your session has expired. Please sign in again."
    }

    @MainActor
    static func postIfNeeded(message: String) async {
        let gateExpired = await SessionGate.shared.isExpired
        let loggingOut = await SessionGate.shared.isLoggingOut
        guard !gateExpired, !loggingOut else { return }
        NotificationCenter.default.post(
            name: .sessionExpired,
            object: nil,
            userInfo: ["message": message]
        )
    }

    nonisolated static func isSessionExpiredMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        let patterns = [
            "session expired",
            "session timeout",
            "session timed out",
            "session has expired",
            "session is expired",
            "session invalid",
            "session not found",
            "invalid session",
            "token expired",
            "token invalid",
            "jwt expired",
            "please login again",
            "please log in again",
            "please sign in again",
            "sign in again",
            "log in again"
        ]
        return patterns.contains { normalized.contains($0) }
    }

    nonisolated private static func apiMessage(from data: Data) -> String? {
        try? JSONDecoder().decode(APIErrorResponse.self, from: data).message
    }
}

// MARK: - Device Session (X25519 movo-info) Expiry Detection

/// Detects the backend signal that the 15-minute X25519 device session (the
/// private key cached in Redis) has expired, so the secure `movo-info` blob can
/// no longer be decrypted. Only consulted for requests that actually sent the
/// X25519 header, so it never affects auth-session expiry.
///
/// Matches on the machine-readable error `code` only — never the status code or
/// message text — so it can't collide with auth-session expiry (which logs the
/// user out via `SessionExpiryNotifier`).
enum DeviceSessionExpiry {

    /// The error `code` the API returns when the device session is
    /// expired/undecryptable. Single source of truth.
    /// TODO(backend): confirm this value against the API contract.
    nonisolated static let expiredCode = "DEVICE_SESSION_EXPIRED"

    nonisolated static func isExpired(code: String?) -> Bool {
        guard let code, !code.isEmpty else { return false }
        return code.caseInsensitiveCompare(expiredCode) == .orderedSame
    }
}
