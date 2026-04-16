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
    case tokenAccess
    case refreshToken(refreshToken: String)
    case enrollRSA(request: RSAEnrollRequest)
    case tokenRSA(request: RSATokenRequest)
    case nonceRSA(request: RSANonceRequest)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .messengerOTP: return "/auth/messenger/otp"
        case .tokenSMS: return "/auth/token-sms/"
        case .tokenAccess: return "/auth/token-access"
        case .refreshToken: return "/auth/refreshToken"
        case .enrollRSA: return "/rsa"
        case .tokenRSA: return "/auth/token-rsa"
        case .nonceRSA: return "/rsa/nonce"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod { .POST } // feature use switch case
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .messengerOTP:
            return .default
        case .tokenSMS:
            return .movoAuthorized
        case .tokenAccess:
            return .movoAuthorized
        case .enrollRSA:
            return .movoAuthorized
        case .nonceRSA:
            return .movoAuthorized
        case .tokenRSA:
            return .movoAuthorized
        case .refreshToken:
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
            let request = MessengerOTPRequest(
                phoneNumber: phoneNumber,
                context: context,
                userAction: "SEND_OTP",
                deviceInfo: .current
            )
            return try JSONEncoder().encode(request)
            
        case .tokenSMS(let phoneNumber, let code):
            let request = TokenSMSRequest(
                phoneNumber: phoneNumber,
                code: code,
                userAction: "VERIFY_OTP")
            return try JSONEncoder().encode(request)
            
        case .tokenAccess:
            let request = UserActionRequest(
                userAction: "GET-ACCESS-TOKEN")
            return try JSONEncoder().encode(request)
            
        case .refreshToken(let refreshToken):
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            return try JSONEncoder().encode(request)
            
        case .enrollRSA(let request):
            return try JSONEncoder().encode(request)

        case .tokenRSA(let request):
            return try JSONEncoder().encode(request)
            
        case .nonceRSA(let request):
            return try JSONEncoder().encode(request)
        }
    }

}
