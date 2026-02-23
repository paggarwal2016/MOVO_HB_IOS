//
//  AuthResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

struct RefreshTokenResponse : Decodable {
    let accessToken: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case refreshToken = "refreshToken"
    }
}

struct SussessResponse: Decodable {
    let success: Bool
    enum CodingKeys: String, CodingKey {
        case success = "success"
    }
}
