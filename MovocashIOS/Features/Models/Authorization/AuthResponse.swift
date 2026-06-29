//
//  AuthResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

nonisolated struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let message: String?
}

nonisolated struct SuccessResponse: Decodable {
    let success: Bool?
    let message: String?
    /// Optional secondary copy (e.g. Send-OTP "Your invite checks out…"). When
    /// present on a successful send, it's shown in a Continue alert before the OTP screen.
    let description: String?
}

nonisolated struct APIErrorResponse: Decodable {
    let message: String
    /// Machine-readable error code (when the API provides one). Used to detect
    /// the device-session-expired condition without string-matching the message.
    let code: String?
}


nonisolated struct RSATokenResponse: Decodable {
    let sessionToken: String
    let message: String?
}

nonisolated struct RSANonceResponse: Decodable {
    let nonce: String
}

nonisolated struct AuthTokenSMSResponse: Decodable {
    let success: Bool
    let sessionId: String
    let message: String?
}

nonisolated struct ConfigureResponse: Decodable {
    let movoSessionConfig: String
    let sessionId: String
}
