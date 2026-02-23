//
//  AuthAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

final class AppEnvironment {
    static let shared = AppEnvironment()
    var current: Environment = .production
    private init() {}
}

enum AuthAPI: Endpoint {
    
    case messengerOTP(phoneNumber: String, context: String)
    case tokenSMS(phoneNumber: String, code: String)
    case refreshToken(refreshToken: String)
    
    // MARK: - Enviroment Configure
    var environment: Environment { AppEnvironment.shared.current }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .messengerOTP: return "/messenger/otp"
        case .tokenSMS: return "/auth/token-sms"
        case .refreshToken: return "/auth/refreshToken"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod { .POST } // feature use switch case
    
    // MARK: - Header Configure
    var header: [String : String]? {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-Device-ID": DeviceManager.shared.deviceID,
            "X-App-Version": AppInfo.version,
            "X-Platform": "iOS",
            "X-Request-ID": UUID().uuidString
        ]
    }
     
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    var body: Data? {
        switch self {
        case .messengerOTP(let phoneNumber, let context):
            let request = MessengerOTPRequest(
                phoneNumber: phoneNumber,
                context: context
            )
            return try? JSONEncoder().encode(request)
        case .tokenSMS(let phoneNumber, let code):
            let request = TokenSMSRequest(
                phoneNumber: phoneNumber,
                code: code
            )
            return try? JSONEncoder().encode(request)
        case .refreshToken(refreshToken: let refreshToken):
            let request = RefreshTokenRequest(
                refreshToken: refreshToken
            )
            return try? JSONEncoder().encode(request)
        }
    }
    
    // MARK: - Auth Requirement
    var requiresAuth: Bool { false }
}
