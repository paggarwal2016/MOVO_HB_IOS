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
    
    static func headers(for type: HeaderType) async -> [String: String] {
        var headers: [String: String] = baseHeaders()
        switch type {
        case .default:
            break
        case .authorized:
            await addAuthorization(&headers)
            
        case .authorizedWithOffice:
            await addAuthorization(&headers)
            headers["office-id"] = "1"
        }
        return headers
    }
}

// MARK: - Default Header

private extension HeaderProvider {
    
    static func baseHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-platform": "ios",
            "x-bundle-id": AppInfo.bundleIdentifier,
            "X-Device-ID": DeviceManager.shared.deviceID,
            "X-App-Version": AppInfo.version,
            "X-Request-ID": UUID().uuidString
        ]
    }
}

// MARK: - Authorization

private extension HeaderProvider {
    
    static func addAuthorization(_ headers: inout [String: String]) async {
        if let token = await AuthManager.shared.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
    }
}
