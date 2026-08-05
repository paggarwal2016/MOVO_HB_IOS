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
    case viewVCard(cardId: Int)
    case activatedVCard
    case physicalVCard(request: PhysicalCardRequest)
    
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
        case .viewVCard(let cardId): return "/vcards/\(cardId)"
        case .activatedVCard: return "/vcards/primary/activated"
        case .physicalVCard: return "/vcards/physical-card"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .getVCardsList:
            return .PUT
        case .getVCardsPrimary, .viewVCard:
            return .PUT
        case .postVCards, .vCardsProvision, .createVCard, .physicalVCard:
            return .POST
        case .activatedVCard:
            return .PATCH
        }
    }
    
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .vCardsProvision, .activatedVCard:
            return [.session, .secureDeviceInfo, .officeId]
        case .getVCardsList, .getVCardsPrimary, .viewVCard:
            return [.session, .secureDeviceInfo, .officeId, .encrypted]
        case .postVCards, .createVCard, .physicalVCard:
            return [.session, .secureDeviceInfo, .officeId, .encrypted, .Idempotency]
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
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET-PRIMARY-CARD"))
        case .getVCardsList:
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET-ALL-CARD"))
        case .postVCards(let request):
            return try JSONEncoder().encode(request)
        case .vCardsProvision(let request):
            return try JSONEncoder().encode(request)
        case .createVCard(let request):
            return try JSONEncoder().encode(request)
        case .viewVCard(let request):
            return try JSONEncoder().encode(request)
        case .activatedVCard:
            return try JSONEncoder().encode(UserActionRequest(userAction: "ACTIVE-PRIMARY-VCARD"))
        case .physicalVCard(let request):
            return try JSONEncoder().encode(request)
        }
    } 
}
