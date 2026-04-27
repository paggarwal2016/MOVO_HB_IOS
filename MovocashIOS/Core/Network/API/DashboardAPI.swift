//
//  DashboardAPI.swift
//  MovocashIOS
//
//  Created by Vinu on 14/04/26.
//

import Foundation

enum DashboardAPI: Endpoint {
    
    case dashboard
    
    // MARK: - API Version
    var version: APIVersion { .v1 }

    // MARK: - URL Path
    var path: String {
        switch self {
        case .dashboard: return "/dashboard"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod { .PUT } // feature use switch case
    
    // MARK: - Header Configure
    var headerType: HeaderType {
        switch self {
        case .dashboard:
            return .movoAuthorized
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
    
    private func encodeBody() throws -> Data {
        switch self {
        case .dashboard:
            let request = UserActionRequest(userAction: "DASHBOARD")
            return try JSONEncoder().encode(request)
        }
    }
}
