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
    case getFavourite(id: String, request: ContactRequest.MarkFavourite)
    case getContacts(request: ContactRequest.GetLists)
    case getFavourites(request: ContactRequest.GetLists)

    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .addFavourite:              return "/contacts/favourite"
        case .deleteFavourite:           return "/fav_contacts"
        case .create:                    return "/contacts"
        case .getFavourite(let id, _):   return "/contacts/\(id)"
        case .getContacts:               return "/contacts"
        case .getFavourites:             return "/fav_contacts"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .addFavourite:    return .POST
        case .deleteFavourite: return .DELETE
        case .create:          return .POST
        case .getFavourite:    return .PATCH
        case .getContacts:     return .PUT
        case .getFavourites:   return .PUT
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType { [.session, .movoInfo] }

    // MARK: - Query Items
    var queryItems: [URLQueryItem]? {
        switch self {
        case .getContacts(let request), .getFavourites(let request):
            return [
                URLQueryItem(name: "responseFlag", value: request.responseFlag),
                URLQueryItem(name: "userAction",   value: request.userAction)
            ]
        default:
            return nil
        }
    }

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
        case .getFavourite(_, let request):
            return try JSONEncoder().encode(request)
        case .getContacts, .getFavourites:
            return nil
        }
    }
}
