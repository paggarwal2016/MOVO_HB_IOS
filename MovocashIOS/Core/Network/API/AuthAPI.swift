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
    case enrollRSA(request: RSAEnrollRequest)
    case tokenRSA(request: RSATokenRequest)
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .messengerOTP: return "/messenger/otp"
        case .tokenSMS: return "/auth/token-sms"
        case .refreshToken: return "/auth/refreshToken"
        case .enrollRSA: return "/rsa"
        case .tokenRSA: return "/auth/token-rsa"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod { .POST } // feature use switch case
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .messengerOTP,.tokenSMS:
            return .default
        case .refreshToken, .enrollRSA, .tokenRSA:
            return .authorized
        }
    }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    var body: Data? {
        get throws {
            try encodeBody()
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
            
        case .enrollRSA(let request):
            SecureLogger.debug("Enroll RSA \(request)", category: .general)
            return try JSONEncoder().encode(request)
            
        case .tokenRSA(let request):
            SecureLogger.debug("Token RSA \(request)", category: .general)
            return try JSONEncoder().encode(request)
        }
    }

}
