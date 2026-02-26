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
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case refreshToken = "refreshToken"
    }
}

nonisolated struct SuccessResponse: Decodable {
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case success = "success"
    }
}

nonisolated struct APIErrorResponse: Decodable {
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case message = "message"
    }
}
