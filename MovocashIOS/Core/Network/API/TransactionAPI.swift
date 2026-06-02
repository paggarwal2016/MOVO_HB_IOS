//
//  TransactionAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

enum TransactionAPI: Endpoint {

    case lists(max: Int, accountId: Int)
    case filtered(TransactionFilter)
    case withdrawals(TransactionRequest.Withdrawal)
    case internals(TransactionRequest.Internal)
    case checkType(TransactionRequest.CheckMode)
    case complete(TransactionRequest.Complete)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .lists, .filtered:   return "/transactions"
        case .withdrawals:        return "/transactions/withdrawal"
        case .internals:          return "/transactions/internal"
        case .checkType:          return "/transactions/check-intent"
        case .complete:           return "/transactions/intent-complete"
        }
    }

    // MARK: - HTTP Method
    var method: HTTPMethod {
        switch self {
        case .lists:       return .PUT
        case .filtered:    return .PUT
        case .withdrawals, .internals, .checkType, .complete: return .POST
        }
    }
    
    // MARK: - Header Configure
    var headerType: HeaderType { [.session, .movoInfo, .Idempotency, .officeId] }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? {
        switch self {
        case .lists(let max, let accountId):
            return [
                URLQueryItem(name: "max",       value: "\(max)"),
                URLQueryItem(name: "accountId", value: "\(accountId)")
            ]
        case .filtered(let filter):
            return filter.queryItems
        case .withdrawals, .internals, .checkType, .complete:
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
        case .filtered:
            let request = UserActionRequest(userAction: "GET-TRANSACATIONS0DETAILS")
            return try JSONEncoder().encode(request)
        case .withdrawals(let request):
            return try JSONEncoder().encode(request)
        case .internals(let request):
            return try JSONEncoder().encode(request)
        case .checkType(let request):
            return try JSONEncoder().encode(request)
        case .complete(let request):
            return try JSONEncoder().encode(request)
        }
    }
}
