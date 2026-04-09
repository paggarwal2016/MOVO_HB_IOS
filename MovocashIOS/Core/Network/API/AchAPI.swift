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
    
    // MARK: - Environment
    
    var environment: Environment { AppConfig.environment }
    
    // MARK: - Path
    
    var path: String {
        switch self {
        case .initiateTransfer:         return "/ach"
        case .getAccounts:              return "/ach/account"
        case .deleteAccount(let id):    return "/ach/account/\(id)"
        case .updateAccount(let id):    return "/ach/account/\(id)"
        }
    }
    
    // MARK: - HTTP Method
    
    var method: HTTPMethod {
        switch self {
        case .initiateTransfer:  return .POST
        case .getAccounts:       return .GET
        case .deleteAccount:     return .DELETE
        case .updateAccount:     return .PATCH
        }
    }
    
    // MARK: - Headers
    
    var headerType: HeaderType {
        switch self {
        case .initiateTransfer:
            return .authorizedWithOffice
        case .getAccounts, .deleteAccount, .updateAccount:
            return .authorized
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
            default:
                return nil
            }
        }
    }
}
