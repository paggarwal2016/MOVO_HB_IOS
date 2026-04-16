//
//  SavingsAccountAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation

enum SavingsAccountAPI: Endpoint {

    case list(sortBy: SavingsSortBy? = nil, sortDirection: SavingsSortDirection? = nil)
    case create(SavingsAccountRequest.CreateAccount)
    case update(SavingsAccountRequest.UpdateAccount)
    case delete(SavingsAccountRequest.DeleteAccount)
    case details(accountId: Int)

    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .list, .create, .update, .delete:
            return "/savings/account"
        case .details(let accountId):
            return "/savings/account/\(accountId)"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .list, .details: return .GET
        case .create:         return .POST
        case .update:         return .PATCH
        case .delete:         return .DELETE
        }
    }

    // MARK: - Header Configure
    var headerType: HeaderType { .movoAuthorized }

    // MARK: - Query Items
    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let sortBy, let sortDirection):
            var items: [URLQueryItem] = []
            if let sortBy {
                items.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))
            }
            if let sortDirection {
                items.append(URLQueryItem(name: "sortDirection", value: sortDirection.rawValue))
            }
            return items.isEmpty ? nil : items
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
        case .list, .details:
            return nil
        case .create(let request):
            return try JSONEncoder().encode(request)
        case .update(let request):
            return try JSONEncoder().encode(request)
        case .delete(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
