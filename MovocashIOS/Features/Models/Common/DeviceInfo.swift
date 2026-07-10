//
//  DeviceInfo.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/04/26.
//

import Foundation
import Security

/// Shared device context attached to any request that requires device identification.
/// - `uuid`     : Stable per-install identifier, Keychain-persisted so it survives cold
///                relaunches. The server binds the X25519 device session to it, so it
///                must NOT change between the session being established and later reuse.
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

    // Keychain account under which the stable per-install uuid is persisted.
    private static let uuidKey = "device_session_uuid"

    /// Stable per-install identifier, persisted in the Keychain rather than
    /// regenerated per process. A request issued after a cold relaunch — e.g. the
    /// biometric-enrollment resume after the user grants Face ID permission in
    /// Settings — must carry the same `uuid` the device session (`/get/config`) was
    /// originally established with. Regenerating it each launch made the reused
    /// session's `movo-info` differ from registration, so the server rejected it.
    /// Read via a raw Keychain query (mirrors `DeviceManager.syncDeviceID`) to stay
    /// synchronous and isolation-agnostic.
    private static let persistentUUID: String = {
        let service = AppInfo.bundleIdentifier + ".secure.keychain"
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uuidKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let existing = String(data: data, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        persistUUID(generated)
        return generated
    }()

    /// Persists the uuid under the same service/account scheme `KeychainManager` uses,
    /// so it is readable on subsequent launches. `AfterFirstUnlockThisDeviceOnly` keeps
    /// it available after a cold relaunch without leaving the device.
    private static func persistUUID(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let service = AppInfo.bundleIdentifier + ".secure.keychain"
        let identity: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uuidKey
        ]
        SecItemDelete(identity as CFDictionary)
        var insert = identity
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static var current: DeviceInfo {
        DeviceInfo(
            uuid: persistentUUID,
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
