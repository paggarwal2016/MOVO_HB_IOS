//
//  HeaderProvider.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import UIKit

// MARK: - HeaderType

/// Composable header flags. Combine with array literal syntax:
///
///     return [.session, .secureDeviceInfo, .officeId]
///
struct HeaderType: OptionSet, Sendable {
    let rawValue: Int

    // MARK: - Individual Flags

    /// Adds `session-id` header from Keychain.
    static let session   = HeaderType(rawValue: 1 << 1)

    /// Adds `office-id` header from AppConfig.
    static let officeId  = HeaderType(rawValue: 1 << 2)

    /// Adds `Authorization: Bearer <access_token>` header from Keychain.
    static let bearer    = HeaderType(rawValue: 1 << 3)

    /// Adds `x-encrypt-response: true` header.
    static let encrypted = HeaderType(rawValue: 1 << 4)
    
    /// Adds `x-encrypt-response: true` header.
    static let Idempotency = HeaderType(rawValue: 1 << 5)

    /// Adds the `movo-info` header — device-info JSON encrypted with the X25519
    /// ECDH → HKDF-SHA256 → AES-256-GCM scheme, formatted as `<sessionId>.<base64Blob>`.
    static let secureDeviceInfo = HeaderType(rawValue: 1 << 6)

    // MARK: - Named Combinations

    /// Base headers only (Content-Type, Accept).
    static let `default`: HeaderType = []
    
    /// movo-info
    static let movoInfos: HeaderType = [.secureDeviceInfo]

    /// session-id + movo-info
    static let movoAuthorized: HeaderType = [.session, .secureDeviceInfo]

    /// session-id + movo-info + office-id
    static let movoAuthorizedWithOffice: HeaderType = [.session, .secureDeviceInfo, .officeId]

    /// session-id + movo-info + office-id + x-encrypt-response
    static let movoAuthorizedAll: HeaderType = [.session, .secureDeviceInfo, .officeId, .encrypted]
    
    /// session-id + movo-info + office-id + x-encrypt-response
    static let movoAuthorizedAllWithIdempotency: HeaderType = [.session, .secureDeviceInfo, .officeId, .encrypted, .Idempotency]

    /// Authorization: Bearer
    static let authorized: HeaderType = [.bearer]

    /// Authorization: Bearer + office-id
    static let authorizedWithOffice: HeaderType = [.bearer, .officeId]
    
    static let movoAuthorizedWithIdempotency: HeaderType = [.session, .secureDeviceInfo, .Idempotency]

    // MARK: - Membership

    /// Bitwise membership test that does NOT go through the `OptionSet`
    /// conformance (which is main-actor isolated under the project's default
    /// isolation). `nonisolated` so it can be called from actor-isolated contexts
    /// such as `NetworkService`.
    nonisolated func has(_ flag: HeaderType) -> Bool {
        (rawValue & flag.rawValue) == flag.rawValue
    }
}

// MARK: - HeaderProvider

struct HeaderProvider {

    static func headers(for type: HeaderType) async -> [String: String] {
        var headers = await baseHeaders()

        if type.contains(.secureDeviceInfo) {
            if let value = await DeviceSessionManager.shared.headerValue() {
                headers["movo-info"] = value
            }
        }

        if type.contains(.session) {
            if let sessionId = try? await KeychainManager.shared.get("auth_session_id", biometricPrompt: nil) {
                headers["session-id"] = sessionId
            }
        }

        if type.contains(.officeId) {
            headers["office-id"] = AppConfig.officeId
        }

        if type.contains(.bearer) {
            if let token = try? await KeychainManager.shared.get("access_token", biometricPrompt: nil),
               !token.isEmpty {
                headers["Authorization"] = "Bearer \(token)"
            }
        }

        if type.contains(.encrypted) {
            headers["x-encrypt-response"] = "true"
        }
        
        if type.contains(.Idempotency) {
            headers["X-Idempotency-Key"] = UUID().uuidString
        }

        return headers
    }
}

// MARK: - Private Helpers

private extension HeaderProvider {

    static func baseHeaders() async -> [String: String] {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }
}
