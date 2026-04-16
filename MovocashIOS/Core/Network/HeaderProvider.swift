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
    case movoAuthorized
    case movoAuthorizedWithOffice
    case movoAuthorizedAll
    case authorized
    case authorizedWithOffice
}

struct HeaderProvider {

    static func headers(for type: HeaderType, authManager: AuthManagerProtocol) async -> [String: String] {
        var headers: [String: String] = await baseHeaders()
        switch type {
        case .default:
            break
        case .movoAuthorized:
            await addMovoAuthorization(&headers)
        case .movoAuthorizedWithOffice:
            await addMovoAuthorization(&headers)
            headers["office-id"] = AppConfig.officeId
        case .movoAuthorizedAll:
            await addMovoAuthorization(&headers)
            headers["office-id"] = AppConfig.officeId
            headers["x-encrypt-response"] = "true"
        case .authorized:
            await addAuthorization(&headers, authManager: authManager)
        case .authorizedWithOffice:
            await addAuthorization(&headers, authManager: authManager)
            headers["office-id"] = AppConfig.officeId
        }
        return headers
    }
}

// MARK: - Private Helpers

private extension HeaderProvider {

    static let movoInfoToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1dWlkIjoiRTlBMDYzMkYtOUM3OS00NTUzLUE5Q0MtMjE3Q0I0RDE4REQ5IiwiZGV2aWNlSWQiOiIwQUI3NzdBNC1DNkY0LTQyRTItOTA5Ny0yMTk3RDQ2MTc4NjIiLCJkZXZpY2VUeXBlIjoiaW9zIiwib3NWZXJzaW9uIjoiMTguNSIsImFwcFZlcnNpb24iOiIxLjAuMCIsImFwcGxpY2F0aW9uTmFtZSI6Im1vdm8taW9zIn0.1epl_aXcG04uAL7RRQMDCemhB9NTGYzOxXjs7ebgOYM"

    static func baseHeaders() async -> [String: String] {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }

    static func addMovoAuthorization(_ headers: inout [String: String]) async {
        if let sessionId = try? await KeychainManager.shared.get("auth_session_id", biometricPrompt: nil) {
            headers["session-id"] = sessionId
        }
        headers["movo-info"] = movoInfoToken
    }

    static func addAuthorization(_ headers: inout [String: String], authManager: AuthManagerProtocol) async {
        if let token = await authManager.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
    }
}
