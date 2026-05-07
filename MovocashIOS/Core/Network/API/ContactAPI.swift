//
//  ContactAPI.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//

import Foundation

enum ContactAPI: Endpoint {

    case addFavourite(request: ContactRequest.AddFavourite)
    case deleteFavourite(request: ContactRequest.DeleteFavourite)
    case create(request: ContactRequest.Create)
    case makeFavourite(id: String, request: ContactRequest.MarkFavourite)
    case getContacts(request: ContactRequest.GetLists)
    case getFavourites(request: ContactRequest.GetLists)
    case getRecent

    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .addFavourite:              return "/contacts/favourite"
        case .deleteFavourite:           return "/contacts"
        case .create:                    return "/contacts"
        case .makeFavourite(let id, _):   return "/contacts/\(id)"
        case .getContacts:               return "/contacts"
        case .getFavourites:             return "/contacts"
        case .getRecent:                 return "/recent-phone-numbers"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .addFavourite:    return .POST
        case .deleteFavourite: return .DELETE
        case .create:          return .POST
        case .makeFavourite:    return .PATCH
        case .getContacts:     return .PUT
        case .getFavourites:   return .PUT
        case .getRecent:       return .GET
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType { [.session, .movoInfo] }

    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { return nil }

    // MARK: - Body
    var body: Data? {
        get throws {
            try encodeBody()
        }
    }

    private func encodeBody() throws -> Data? {
        switch self {
        case .addFavourite(let request):
            return try JSONEncoder().encode(request)
        case .deleteFavourite(let request):
            return try JSONEncoder().encode(request)
        case .create(let request):
            return try JSONEncoder().encode(request)
        case .makeFavourite(_, let request):
            return try JSONEncoder().encode(request)
        case .getContacts(let request), .getFavourites(let request):
            return try JSONEncoder().encode(request)
        case .getRecent:
            return nil
            //try JSONEncoder().encode(UserActionRequest(userAction: "GET-RECENT"))
        }
    }
}
