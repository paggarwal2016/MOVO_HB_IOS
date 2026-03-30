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
}

struct TokenSMSRequest: Encodable, Sendable {
    let phoneNumber: String
    let code: String
}

struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

// MARK: - RSA

struct RSAEnrollRequest: Encodable, Sendable {
    let publicKey: String
    let deviceId: String
}

struct RSATokenRequest: Encodable, Sendable {
    let signedMessage: String
    let deviceId: String
}
