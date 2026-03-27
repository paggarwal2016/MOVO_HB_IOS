//
//  RewardAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/03/26.
//

import Foundation

enum RewardAPI: Endpoint {
    
    case getReward
    case postReward
    case enrollReward
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .getReward, .postReward: return "/rewards"
        case .enrollReward: return "rewards/enrollment"
        }
    }
    
    //MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getReward, .enrollReward:
            return .GET
        case .postReward:
            return .POST
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType { .authorized }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    var body: Data? {
        nil
    }
}
