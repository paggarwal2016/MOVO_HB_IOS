//
//  ContactAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/05/26.
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
    case referralInvite(request: ContactRequest.Referral)
    case referrelInviteList

    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .addFavourite:                return "/contacts/favourite"
        case .deleteFavourite:             return "/contacts"
        case .create:                      return "/contacts"
        case .makeFavourite(let id, _):    return "/contacts/\(id)"
        case .getContacts:                 return "/contacts"
        case .getFavourites:               return "/contacts"
        case .getRecent:                   return "/recent-transfer"
        case .referralInvite:              return "/referral/invite"
        case .referrelInviteList:          return "/referral/invite"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .addFavourite:       return .POST
        case .deleteFavourite:    return .DELETE
        case .create:             return .POST
        case .makeFavourite:      return .PATCH
        case .getContacts:        return .PUT
        case .getFavourites:      return .PUT
        case .getRecent:          return .PUT
        case .referralInvite:     return .POST
        case .referrelInviteList: return .PUT
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType { [.session, .secureDeviceInfo, .officeId] }

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
            return try JSONEncoder().encode(UserActionRequest(userAction: "RECENT-TRANSFER"))
        case .referralInvite(let request):
            return try JSONEncoder().encode(request)
        case .referrelInviteList:
            return try JSONEncoder().encode(UserActionRequest(userAction: "GET-REFERRAL-LIST"))
        }
    }
}
