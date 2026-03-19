//
//  HeaderProvider.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

// MARK: - Enum - HeaderType

enum HeaderType: Sendable {
    case `default`
    case authorized
    case authorizedWithOffice
}

struct HeaderProvider {

    static func headers(for type: HeaderType, authManager: AuthManagerProtocol) async -> [String: String] {
        var headers: [String: String] = await baseHeaders()
        switch type {
        case .default:
            break
        case .authorized:
            await addAuthorization(&headers, authManager: authManager)

        case .authorizedWithOffice:
            await addAuthorization(&headers, authManager: authManager)
            headers["office-id"] = AppConfig.officeId
        }
        return headers
    }
}

// MARK: - Default Header

private extension HeaderProvider {
    
    static func baseHeaders() async -> [String: String] {
        let deviceID = await DeviceManager.shared.deviceID()
        return [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-platform": "ios",
            "x-bundle-id": AppInfo.bundleIdentifier,
            "X-Device-ID": deviceID,
            "X-App-Version": AppInfo.version,
            "X-Request-ID": UUID().uuidString
        ]
    }
}

// MARK: - Authorization

private extension HeaderProvider {
    
    static func addAuthorization(_ headers: inout [String: String], authManager: AuthManagerProtocol) async {
        if let token = await authManager.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
    }
}
