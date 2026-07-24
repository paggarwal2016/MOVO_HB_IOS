//
//  NetworkError.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import Foundation
import MobileBankingSDK

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
    /// Broadcast when any API responds with HTTP 426 (Upgrade Required). Observed by
    /// RootView to raise the app-wide mandatory-update gate. The server's message is
    /// carried in `userInfo["message"]`. See `AppUpdateNotifier`.
    static let appUpdateRequired = Notification.Name("appUpdateRequired")
}

// MARK: - App Update Broadcast

/// Central, main-actor broadcaster for the mandatory-update signal. Any API that
/// returns HTTP 426 posts through here so the SwiftUI gate in `RootView` raises on
/// the main actor without cross-thread `@State` mutation.
enum AppUpdateNotifier {
    @MainActor static func broadcastUpdateRequired(message: String?, endpoint: String? = nil) {
        var params: [String: Any] = [AnalyticsParam.statusCode: 426]
        if let endpoint, !endpoint.isEmpty { params[AnalyticsParam.endpoint] = endpoint }
        if let message, !message.isEmpty { params[AnalyticsParam.errorMessage] = message }
        AnalyticsManager.shared.log(AnalyticsEvent.appUpdateRequired426, params: params)

        NotificationCenter.default.post(
            name: .appUpdateRequired,
            object: nil,
            userInfo: message.map { ["message": $0] }
        )
    }
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
    /// HTTP 426 — the client is too old and must update. Handled centrally by the
    /// app-update gate, not by per-call toasts.
    case updateRequired(message: String?)
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

        case .updateRequired(let message):
            return message ?? "A new version is available. Please update to continue."

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
        if let error = self as? NetworkError {
            switch error {
            // Handled centrally (session gate / update gate) — no duplicate toast.
            case .unauthorized, .updateRequired: return false
            default: break
            }
        }
        return true
    }

    var analyticsCode: String {
        if self is CancellationError { return "cancelled" }
        if let net = self as? NetworkError { return net.analyticsCode }
        return String(describing: type(of: self))
    }
}

extension NetworkError {
    var analyticsCode: String {
        switch self {
        case .invalidResponse:        return "invalid_response"
        case .unauthorized:           return "unauthorized"
        case .decodingError:          return "decoding_error"
        case .serverMessage:          return "server_message"
        case .apiError(let code):     return "http_\(code)"
        case .rateLimited:            return "rate_limited"
        case .serverError:            return "server_error"
        case .noInternet:             return "no_internet"
        case .timeout:                return "timeout"
        case .requestFailed:          return "request_failed"
        case .securityViolation:      return "security_violation"
        case .secureConnectionFailed: return "secure_connection_failed"
        case .invalidURL:             return "invalid_url"
        case .encodingError:          return "encoding_error"
        case .noContent:              return "no_content"
        case .deviceSessionExpired:   return "device_session_expired"
        case .updateRequired:         return "update_required"
        case .unknown:                return "unknown"
        }
    }
}

// MARK: - Server Error Message Extraction

/// Derives a user-displayable message from an error response body so the server's
/// own wording is surfaced instead of a canned client string. Prefers the
/// structured JSON contract (`APIErrorResponse.message`); when the body is not that
/// JSON (e.g. a gateway HTML rate-limit page such as `<title>429</title>429 Too
/// Many Requests`), falls back to the body's readable text. Returns nil when no
/// meaningful text can be recovered, so the caller can use its per-status default.
enum ServerErrorMessage {

    /// Toasts should stay short — cap recovered text so a verbose error page can't
    /// flood the UI.
    nonisolated private static let maxLength = 300

    nonisolated static func extract(from data: Data) -> String? {
        if let json = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            let message = json.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { return message }
        }

        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A JSON body that didn't match our error contract isn't user-displayable
        // text — don't dump raw JSON into a toast; let the caller fall back.
        guard !trimmed.isEmpty, !trimmed.hasPrefix("{"), !trimmed.hasPrefix("[") else { return nil }
        return readableText(from: trimmed)
    }

    /// Strips markup and collapses whitespace to recover the human-readable text
    /// from an HTML/plain-text error body.
    nonisolated static func readableText(from raw: String) -> String? {
        // Preserve <title> text as a fallback before its element is removed.
        let titleText = firstCapture(in: raw, pattern: "<title[^>]*>([\\s\\S]*?)</title>")

        var text = raw
        // Drop non-content elements outright (tag + inner text) so their contents
        // (e.g. a duplicated status code in <title>) don't leak into the message.
        for element in ["script", "style", "title"] {
            text = text.replacingOccurrences(
                of: "<\(element)[^>]*>[\\s\\S]*?</\(element)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Strip any remaining tags.
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        let body = normalize(text)
        let candidate = body.isEmpty ? normalize(titleText ?? "") : body
        guard !candidate.isEmpty else { return nil }
        return String(candidate.prefix(maxLength))
    }

    /// Decodes the handful of entities that appear in plain error pages, then
    /// collapses whitespace runs to single spaces and trims.
    nonisolated private static func normalize(_ input: String) -> String {
        var text = input
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&nbsp;": " "]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
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
