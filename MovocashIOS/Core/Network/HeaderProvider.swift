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
///     return [.session, .movoInfo, .officeId]
///
struct HeaderType: OptionSet, Sendable {
    let rawValue: Int

    // MARK: - Individual Flags

    /// Adds `movo-info` JWT header.
    static let movoInfo  = HeaderType(rawValue: 1 << 0)

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

    // MARK: - Named Combinations

    /// Base headers only (Content-Type, Accept).
    static let `default`: HeaderType = []
    
    /// movo-info
    static let movoInfos: HeaderType = [.movoInfo]

    /// session-id + movo-info
    static let movoAuthorized: HeaderType = [.session, .movoInfo]

    /// session-id + movo-info + office-id
    static let movoAuthorizedWithOffice: HeaderType = [.session, .movoInfo, .officeId]

    /// session-id + movo-info + office-id + x-encrypt-response
    static let movoAuthorizedAll: HeaderType = [.session, .movoInfo, .officeId, .encrypted]
    
    /// session-id + movo-info + office-id + x-encrypt-response
    static let movoAuthorizedAllWithIdempotency: HeaderType = [.session, .movoInfo, .officeId, .encrypted, .Idempotency]

    /// Authorization: Bearer
    static let authorized: HeaderType = [.bearer]

    /// Authorization: Bearer + office-id
    static let authorizedWithOffice: HeaderType = [.bearer, .officeId]
    
    static let movoAuthorizedWithIdempotency: HeaderType = [.session, .movoInfo, .Idempotency]
}

// MARK: - HeaderProvider

struct HeaderProvider {

    static func headers(for type: HeaderType) async -> [String: String] {
        var headers = await baseHeaders()

        if type.contains(.movoInfo) {
            headers["movo-info"] = await movoInfoToken()
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

    /// Builds the `movo-info` header: the device-info JSON encrypted with RSA-OAEP
    /// (SHA-256) using the server's public key (`movoSessionConfig`, stored in the
    /// Keychain by `configure()`), returned as a raw standard-base64 blob — the exact
    /// format the server's `base64decode` + RSA decrypt expects. Returns an empty
    /// string if the key or device-info payload is unavailable.
    static func movoInfoToken() async -> String {
        guard let publicKey = try? await KeychainManager.shared.get("movo_session_config", biometricPrompt: nil),
              !publicKey.isEmpty else {
            SecureLogger.error("movo-info: signing key missing — configure() not completed", category: .network)
            return ""
        }

        do {
            let payloadData = try JSONEncoder().encode(DeviceInfo.current)
            return try SealedCryptoService.rsaOAEPEncrypt(payloadData, publicKeyBase64: publicKey)
        } catch {
            SecureLogger.error("movo-info: encryption failed — \(error.localizedDescription)", category: .network)
            return ""
        }
    }

    static func baseHeaders() async -> [String: String] {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }
}
