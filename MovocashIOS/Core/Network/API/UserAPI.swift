//
//  UserAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation

enum UserAPI: Endpoint {
    
    case getProfile
    case deleteProfile
    case profileTOS
    case profileVirtualCardTOS
    case saveUser(request: SaveUserRequest)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .getProfile: return "/users/profile"
        case .deleteProfile: return "/users"
        case .profileTOS: return "/users/profile/tos"
        case .profileVirtualCardTOS: return "/users/profile/virtual-card-tos"
        case .saveUser: return "/user/data"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getProfile:
            return .PUT
        case .deleteProfile:
            return .DELETE
        case .profileTOS, .profileVirtualCardTOS:
            return .PUT
        case .saveUser:
            return .POST
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .getProfile, .profileTOS, .profileVirtualCardTOS, .saveUser: return .movoAuthorized
        case .deleteProfile: return .authorizedWithOffice
        }
    }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    var body: Data? {
        get throws {
            try encodeBody()
        }
    }
    
    private func encodeBody() throws -> Data? {
        switch self {
        case .getProfile:
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET-USER-DATA"))
        case .deleteProfile, .profileTOS, .profileVirtualCardTOS:
            return nil
        case .saveUser(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
