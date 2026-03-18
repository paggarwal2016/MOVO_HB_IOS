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
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .getProfile: return "/users/profile"
        case .deleteProfile: return "/users"
        case .profileTOS: return "/users/profile/tos"
        case .profileVirtualCardTOS: return "/users/profile/virtual-card-tos"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getProfile:
            return .GET
        case .deleteProfile:
            return .DELETE
        case .profileTOS, .profileVirtualCardTOS:
            return .PUT
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .getProfile, .profileTOS, .profileVirtualCardTOS: return .authorized
        case .deleteProfile: return .authorizedWithOffice
        }
    }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    var body: Data? {
        nil
    }
}
