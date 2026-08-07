//
//  AttestAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 07/07/26.
//

import Foundation

enum AttestAPI: Endpoint {

    case challenge
    case register(request: AttestRegisterRequest)

    var isAuth: Bool { true }

    var version: APIVersion { .v1 }

    var path: String {
        switch self {
        case .challenge: return "/attest/challenge"
        case .register:  return "/attest/register"
        }
    }

    var method: HTTPMethod { .POST }

    var headerType: HeaderType {
        switch self {
        case .challenge, .register:
            return [.officeId]
        }
    }

    var queryItems: [URLQueryItem]? { nil }

    var body: Data? {
        get throws {
            switch self {
            case .challenge:
                return nil
            case .register(let request):
                return try JSONEncoder().encode(request)
            }
        }
    }
}







// MARK: - Models

nonisolated struct AttestChallengeResponse: Decodable, Sendable {
    let challenge: String
}

nonisolated struct AttestRegisterRequest: Encodable, Sendable {
    let keyId: String
    let attestation: String
    let challenge: String
}

nonisolated struct AttestRegisterResponse: Decodable, Sendable {
    let success: Bool?
    let message: String?
}
