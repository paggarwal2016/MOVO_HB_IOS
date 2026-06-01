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
    case emailOTP(request: EmailVerifyRequest)
    case emailVerify(request: EmailOTPRequest)
    case tokenAccess
    case acceptAgreements
    case enrollRSA(request: RSAEnrollRequest)
    case tokenRSA(request: RSATokenRequest)
    case nonceRSA(request: RSANonceRequest)
    case configure
    case logout
    
    var isAuth: Bool { true }

    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .messengerOTP:      return "/auth/messenger/otp"
        case .tokenSMS:          return "/auth/token-sms"
        case .emailOTP:          return "/auth/email/otp"
        case .emailVerify:       return "/auth/email/verify"
        case .tokenAccess:       return "/auth/token-access"
        case .acceptAgreements:  return "/user/profile/accept-agreements"
        case .enrollRSA:         return "/rsa"
        case .tokenRSA:          return "/auth/token-rsa"
        case .nonceRSA:          return "/rsa/nonce"
        case .configure:         return "/get/config"
        case .logout:            return "/auth/logout"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .messengerOTP, .tokenSMS, .tokenAccess,
                .enrollRSA, .tokenRSA, .nonceRSA, .logout, .emailOTP, .emailVerify, .acceptAgreements:
            return .POST
        case .configure:
            return .GET
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .messengerOTP:
            return [.officeId]
        case .tokenSMS,
             .tokenRSA,
             .nonceRSA:
            return [.officeId, .movoInfo]
        case .emailOTP,
             .emailVerify,
             .tokenAccess,
             .acceptAgreements,
             .enrollRSA,
             .logout:
            return .movoAuthorized
        case .configure:
            return .default
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
    
    private func encodeBody() throws -> Data? {
        switch self {
        case .messengerOTP(let request):
            return try JSONEncoder().encode(request)
        case .tokenSMS(let request):
            return try JSONEncoder().encode(request)
        case .emailOTP(let request):
            return try JSONEncoder().encode(request)
        case .emailVerify(let request):
            return try JSONEncoder().encode(request)
        case .tokenAccess:
            let request = UserActionRequest(
                userAction: "GET_ACCESS_TOKEN")
            return try JSONEncoder().encode(request)
        case .acceptAgreements:
            let request = AgreementRequest(accepted: true, Agreement: [Agreement(AgreementType: .ecc, action: .accepted), Agreement(AgreementType: .tos, action: .accepted), Agreement(AgreementType: .virtualCardTos, action: .accepted)], userAction: "AGREEMENT")
            return try JSONEncoder().encode(request)
        case .enrollRSA(let request):
            return try JSONEncoder().encode(request)
        case .tokenRSA(let request):
            return try JSONEncoder().encode(request)
        case .nonceRSA(let request):
            return try JSONEncoder().encode(request)
        case .configure:
            return nil
        case .logout:
            let request = UserActionRequest(
                userAction: "LOGOUT")
            return try JSONEncoder().encode(request)
        }
    }
}
