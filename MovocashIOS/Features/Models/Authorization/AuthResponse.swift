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
}

nonisolated struct APIErrorResponse: Decodable {
    let message: String
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
}
