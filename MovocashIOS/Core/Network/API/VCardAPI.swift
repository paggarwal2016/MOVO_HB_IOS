//
//  VCardAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

enum VCardAPI: Endpoint {
    
    case getVCards
    case getVCardsPrimary
    case getVCardsList
    case postVCards(request: VCardsRequest)
    case vCardsProvision(request: VCardsProvisionRequest)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .getVCards, .postVCards: return "/vcards"
        case .getVCardsPrimary: return "/vcards/primary"
        case .getVCardsList: return "/vcards/all"
        case .vCardsProvision: return "/vcards/provision"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getVCards, .getVCardsPrimary, .getVCardsList:
            return .GET
        case .postVCards, .vCardsProvision:
            return .POST
        }
    }
    
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .getVCards, .vCardsProvision, .getVCardsPrimary, .getVCardsList:
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
        case .getVCards, .getVCardsPrimary, .getVCardsList:
            return nil
            
        case .postVCards(let request):
            return try JSONEncoder().encode(request)
            
        case .vCardsProvision(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
