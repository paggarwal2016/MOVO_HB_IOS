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
    let osVersion: String
    let appVersion: String
    let applicationName: String

    // Generated once per app session — same across all requests, resets on relaunch
    private static let sessionUUID: String = UUID().uuidString

    static var current: DeviceInfo { // TODO : Vinu
        DeviceInfo(
            uuid: "E9A0632F-9C79-4553-A9CC-217CB4D18DD9",// trackable — stable per session
            deviceId: "0AB777A4-C6F4-42E2-9097-2197D4617862",   // permanent — Keychain persisted
            deviceType: "ios",
            osVersion: "18.5",
            appVersion: "4.3.3",
            applicationName: "movo-ios"
        )
    }

    // MARK: - Base64

    var base64Encoded: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }
}


//static var current: DeviceInfo { // TODO : Vinu
//    DeviceInfo(
//        uuid: sessionUUID                            // trackable — stable per session
//        deviceId: DeviceManager.shared.syncDeviceID,   // permanent — Keychain persisted
//        deviceType: AppInfo.platform,
//        osVersion: AppInfo.osVersion,
//        appVersion: AppInfo.version,
//        applicationName: AppInfo.applicationName
//    )
//}
