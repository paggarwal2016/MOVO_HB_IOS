//
//  AuthRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

// MARK: - Messenger OTP

struct MessengerOTPRequest: Encodable, Sendable {
    let phoneNumber: String
    let context: String
    let userAction: String
    let deviceInfo: DeviceInfo
}

struct TokenSMSRequest: Encodable, Sendable {
    let phoneNumber: String
    let code: String
    let userAction: String
}

struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

// MARK: - RSA

struct RSAEnrollRequest: Encodable, Sendable {
    let publicKey: String
    let deviceId: String
    let userAction: String
}

struct RSATokenRequest: Encodable, Sendable {
    let signedMessage: String
    let deviceId: String
    let userAction: String
}

struct RSANonceRequest: Encodable, Sendable {
    let deviceId: String
    let userAction: String
}

struct UserActionRequest: Encodable, Sendable {
    let userAction: String
}

