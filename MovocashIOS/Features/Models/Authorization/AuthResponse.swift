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
        case success
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        success = (try? container?.decodeIfPresent(Bool.self, forKey: .success)) ?? true
    }
}

nonisolated struct APIErrorResponse: Decodable {
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case message = "message"
    }
}


nonisolated struct RSATokenResponse: Decodable {
    let accessToken:  String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case refreshToken = "refreshToken"
    }
}
