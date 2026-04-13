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
