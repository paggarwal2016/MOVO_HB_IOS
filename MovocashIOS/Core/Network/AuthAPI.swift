//
//  AuthAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

enum AuthAPI: Endpoint {
    
    case messengerOTP(phoneNumber: String, context: String)
    case tokenSMS(phoneNumber: String, code: String)
    case refreshToken(refreshToken: String)
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
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
    
    // MARK: - Body (Safe Encoding)
    var body: Data? {
        do {
            return try encodeBody()
        } catch {
            return nil
        }
    }
    
    private func encodeBody() throws -> Data {
        switch self {
        case .messengerOTP(let phoneNumber, let context):
            let request = MessengerOTPRequest(phoneNumber: phoneNumber, context: context)
            return try JSONEncoder().encode(request)
            
        case .tokenSMS(let phoneNumber, let code):
            let request = TokenSMSRequest(phoneNumber: phoneNumber, code: code)
            return try JSONEncoder().encode(request)
            
        case .refreshToken(let refreshToken):
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            return try JSONEncoder().encode(request)
        }
    }
    
    // MARK: - Auth Requirement
    var requiresAuth: Bool { false }
}
