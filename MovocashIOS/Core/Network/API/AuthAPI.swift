//
//  AuthAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

enum AuthAPI: Endpoint {
    
    case messengerOTP(request: MessengerOTPRequest)
    case tokenSMS(request: TokenSMSRequest)
    case tokenAccess
    case enrollRSA(request: RSAEnrollRequest)
    case tokenRSA(request: RSATokenRequest)
    case nonceRSA(request: RSANonceRequest)
    case logout
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .messengerOTP: return "/auth/messenger/otp"
        case .tokenSMS:     return "/auth/token-sms"
        case .tokenAccess:  return "/auth/token-access"
        case .enrollRSA:    return "/rsa"
        case .tokenRSA:     return "/auth/token-rsa"
        case .nonceRSA:     return "/rsa/nonce"
        case .logout:       return "/auth/logout"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .messengerOTP, .tokenSMS, .tokenAccess,
                .enrollRSA, .tokenRSA, .nonceRSA, .logout:
            return .POST
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .messengerOTP:
            return .default
        case .tokenSMS:
            return .movoInfos
        case .tokenAccess:
            return .movoAuthorized
        case .enrollRSA:
            return .movoAuthorized
        case .nonceRSA:
            return .movoInfos
        case .tokenRSA:
            return .movoInfos
        case .logout:
            return .movoAuthorized
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
        case .messengerOTP(let request):
            return try JSONEncoder().encode(request)
            
        case .tokenSMS(let request):
            return try JSONEncoder().encode(request)
            
        case .tokenAccess:
            let request = UserActionRequest(
                userAction: "GET_ACCESS_TOKEN")
            return try JSONEncoder().encode(request)
            
        case .enrollRSA(let request):
            return try JSONEncoder().encode(request)

        case .tokenRSA(let request):
            return try JSONEncoder().encode(request)
            
        case .nonceRSA(let request):
            return try JSONEncoder().encode(request)
        case .logout:
            let request = UserActionRequest(
                userAction: "LOGOUT")
            return try JSONEncoder().encode(request)
        }
    }

}
