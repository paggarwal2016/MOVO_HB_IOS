//
//  DeviceInfo.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/04/26.
//

import Foundation

/// Shared device context attached to any request that requires device identification.
/// - `uuid`     : Temporary — generated once per app session, resets on relaunch. Used for request tracing.
/// - `deviceId` : Permanent — Keychain-persisted stable device identity.
struct DeviceInfo: Encodable, Sendable {
    let uuid: String
    let deviceId: String
    let deviceType: String
    let appVersion: String
    let appName: String

    // Generated once per app session — same across all requests, resets on relaunch
    private static let sessionUUID: String = UUID().uuidString

    static var current: DeviceInfo {
        DeviceInfo(
            uuid: sessionUUID,                              // trackable — stable per session
            deviceId: DeviceManager.shared.syncDeviceID,   // permanent — Keychain persisted
            deviceType: AppInfo.platform,
            appVersion: AppInfo.version,
            appName: AppInfo.appName
        )
    }

    // MARK: - Base64

    var base64Encoded: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }
}



import Foundation
import CryptoKit

struct DeviceInfo1: Encodable, Sendable {
    let uuid: String
    let deviceId: String
    let deviceType: String
    let appVersion: String
    let applicationName: String          // ← renamed from appName

    private static let sessionUUID: String = UUID().uuidString

    static var current: DeviceInfo1 {
        DeviceInfo1(
            uuid: sessionUUID,
            deviceId: DeviceManager.shared.syncDeviceID,
            deviceType: AppInfo.platform,
            appVersion: AppInfo.version,
            applicationName: AppInfo.appName   // ← updated label
        )
    }

    // MARK: - JWT

    func jwtEncoded(secret: String) -> String? {
        // 1. Header
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let headerB64 = base64URLEncode(Data(header.utf8))

        // 2. Payload
        guard let payloadData = try? JSONEncoder().encode(self) else { return nil }
        let payloadB64 = base64URLEncode(payloadData)

        // 3. Signature — HMAC-SHA256
        let signingInput = "\(headerB64).\(payloadB64)"
        guard let keyData = secret.data(using: .utf8) else { return nil }
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8),
            using: key
        )
        let signatureB64 = base64URLEncode(Data(signature))

        return "\(signingInput).\(signatureB64)"
    }

    // MARK: - Helpers

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")   // no padding in JWT
    }
}
