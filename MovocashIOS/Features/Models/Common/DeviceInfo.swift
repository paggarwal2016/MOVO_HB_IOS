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
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let applicationName: String

    // Generated once per app session — same across all requests, resets on relaunch
    private static let sessionUUID: String = UUID().uuidString
    
    static var current: DeviceInfo {
        DeviceInfo(
            uuid: sessionUUID,
            deviceId: DeviceManager.shared.syncDeviceID,
            deviceType: AppInfo.platform,
            deviceName: AppInfo.deviceName,
            deviceModel: AppInfo.deviceModel,
            osVersion: AppInfo.osVersion,
            appVersion: AppInfo.version,
            applicationName: AppInfo.applicationName
        )
    }

    // MARK: - Base64

    var base64Encoded: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }
}
