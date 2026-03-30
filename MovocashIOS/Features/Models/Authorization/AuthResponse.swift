//
//  AuthResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

nonisolated struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

nonisolated struct SuccessResponse: Decodable {
    let success: Bool?
}

nonisolated struct APIErrorResponse: Decodable {
    let message: String
}


nonisolated struct RSATokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
