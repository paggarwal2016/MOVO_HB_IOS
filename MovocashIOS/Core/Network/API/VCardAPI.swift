//
//  VCardAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

enum VCardAPI: Endpoint {
    
    case getVCardsPrimary
    case getVCardsList
    case postVCards(request: VCardsRequest)
    case vCardsProvision(request: VCardsProvisionRequest)
    case createVCard(request: CreateVCardRequest)
    // /vcards/537 - i need to call
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .postVCards: return "/vcards"
        case .getVCardsPrimary: return "/vcards/primary"
        case .getVCardsList: return "/vcards/all"
        case .vCardsProvision: return "/vcards/provision"
        case .createVCard: return "/vcards/create-vcard"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getVCardsList:
            return .PUT
        case .getVCardsPrimary:
            return .PUT
        case .postVCards, .vCardsProvision, .createVCard:
            return .POST
        }
    }
    
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .vCardsProvision:
            return .movoAuthorized
        case .getVCardsList, .getVCardsPrimary:
            return .movoAuthorizedAll
        case .postVCards:
            return .movoAuthorizedAllWithIdempotency
        case .createVCard:
            return .movoAuthorizedAllWithIdempotency
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
        case .getVCardsPrimary:
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET_PRIMARY_CARD"))
        case .getVCardsList:
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET-ALL-CARD"))
        case .postVCards(let request):
            return try JSONEncoder().encode(request)
        case .vCardsProvision(let request):
            return try JSONEncoder().encode(request)
        case .createVCard(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
