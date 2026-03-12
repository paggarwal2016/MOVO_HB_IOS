//
//  VCardAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

enum VCardAPI: Endpoint {
    
    case getVCards
    case postVCards(request: VCardsRequest)
    case vCardsProvision(request: VCardsProvisionRequest)
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .getVCards, .postVCards: return "/vcards"
        case .vCardsProvision: return "/vcards/provision"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getVCards:
            return .GET
        case .postVCards, .vCardsProvision:
            return .POST
        }
    }
    
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .getVCards, .vCardsProvision:
            return .authorized
        case .postVCards:
            return .authorizedWithOffice
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
        case .getVCards:
            return nil
            
        case .postVCards(let request):
            return try JSONEncoder().encode(request)
            
        case .vCardsProvision(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
