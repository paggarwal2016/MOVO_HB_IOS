//
//  AchAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation

enum AchAPI: Endpoint {
    
    case initiateTransfer(ACHRequest)
    case getAccounts
    case deleteAccount(id: Int)
    case updateAccount(id: Int)
    case achPlaidAccount(request: PlaidAccountRequest)
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - Path
    
    var path: String {
        switch self {
        case .initiateTransfer:         return "/ach"
        case .getAccounts:              return "/ach/account"
        case .deleteAccount(let id):    return "/ach/account/\(id)"
        case .updateAccount(let id):    return "/ach/account/\(id)"
        case .achPlaidAccount:          return "/ach/plaid/accounts"
        }
    }
    
    // MARK: - HTTP Method
    
    var method: HTTPMethod {
        switch self {
        case .initiateTransfer, .achPlaidAccount:  return .POST
        case .getAccounts:       return .PUT
        case .deleteAccount:     return .DELETE
        case .updateAccount:     return .PATCH
        }
    }
    
    // MARK: - Headers
    
    var headerType: HeaderType {
        switch self {
        case .initiateTransfer:
            return [.session, .secureDeviceInfo, .Idempotency, .officeId]
        case .getAccounts, .deleteAccount, .updateAccount, .achPlaidAccount:
            return [.session, .secureDeviceInfo, .officeId]
        }
    }
    
    // MARK: - Query Items
    
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    
    var body: Data? {
        get throws {
            switch self {
            case .initiateTransfer(let request):
                return try JSONEncoder().encode(request)
            case .getAccounts:
                return try JSONEncoder().encode(UserActionRequest(userAction: "GET-ACH-ACCOUNTS"))
            case .deleteAccount:
                return try JSONEncoder().encode(UserActionRequest(userAction: "DELETE-ACH-ACCOUNTS"))
            case .updateAccount:
                return try JSONEncoder().encode(UserActionRequest(userAction: "SET-DEFAULT-ACCOUNT"))
            case .achPlaidAccount(let request):
                return try JSONEncoder().encode(request)
            }
        }
    }
}
