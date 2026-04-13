//
//  TransactionAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

enum TransactionAPI: Endpoint {
    
    case lists(max: Int, accountId: Int)
    case withdrawals(TransactionRequest.Withdrawal)
    case internals(TransactionRequest.Internal)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .lists: return "/transactions"
        case .withdrawals: return "/transactions/withdrawal"
        case .internals: return "/transactions/internal"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .lists: return .GET
        case .withdrawals, .internals: return .POST
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType { .authorized }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? {
        switch self {
        case .lists(let max, let accountId):
            return [
                URLQueryItem(name: "max", value: "\(max)"),
                URLQueryItem(name: "accountId", value: "\(accountId)")
            ]
        case .withdrawals, .internals:
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
        case .lists:
            return nil
        case .withdrawals(let request):
            return try JSONEncoder().encode(request)
        case .internals(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
