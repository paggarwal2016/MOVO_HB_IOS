//
//  AuthRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

struct MessengerOTPRequest: Encodable, Sendable {
    let phoneNumber: String
    let context: String
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phoneNumber"
        case context = "context"
    }
}

struct TokenSMSRequest: Encodable, Sendable {
    let phoneNumber: String
    let code: String
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phoneNumber"
        case code = "code"
    }
}

struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refreshToken"
    }
}
