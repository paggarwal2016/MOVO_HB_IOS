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

// MARK: - Waitlist

struct WaitListRequest: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let deviceInfo: DeviceInfo
    let userAction: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName  = "last_name"
        case email
        case phoneNumber = "invitee_phone"
        case deviceInfo
        case userAction
    }
}

// MARK: - Email

struct EmailVerifyRequest: Encodable, Sendable {
    let email: String
    let userAction: String
}

struct EmailOTPRequest: Encodable, Sendable {
    let code: String
    let userAction: String
}


// MARK: - Agreement

struct AgreementRequest: Encodable, Sendable {
    let accepted: Bool
    let Agreement: [Agreement]
    let userAction: String
}

struct Agreement: Encodable, Sendable {
    let AgreementType: AgreementType
    let action: AgreementActionType
}

enum AgreementType: String, Codable {
    case ecc = "ECC"
    case tos = "TOS"
    case virtualCardTos = "virtual-card-tos"
}

enum AgreementActionType: String, Codable {
    case accepted = "T"
    case rejected = "F"
}

struct SetPasswordRequest: Encodable, Sendable {
    let password: String
}

struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String
}
