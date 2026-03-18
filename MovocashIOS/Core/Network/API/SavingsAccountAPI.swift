//
//  SavingsAccountAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation

enum SavingsAccountAPI: Endpoint {
    
    case list
    case create(SavingsAccountRequest.CreateAccount)
    case update(SavingsAccountRequest.UpdateAccount)
    case delete(SavingsAccountRequest.DeleteAccount)
    case details(accountId: Int)
    
    // MARK: - Environment Configure
    var environment: Environment { AppConfig.environment }
    
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
        case .create: return .POST
        case .update: return .PATCH
        case .delete: return .DELETE
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType { .authorized }
    
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

