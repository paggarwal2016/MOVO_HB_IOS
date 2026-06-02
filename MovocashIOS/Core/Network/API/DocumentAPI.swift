//
//  DocumentAPI.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/05/26.
//

import Foundation

enum DocumentAPI: Endpoint {
    
    case tos
    case privacy
    case herringPrivacy
    case cardholderAgreement
    
    // MARK: - API Version
    var version: APIVersion { .v1 }
    
    // MARK: - URL Path
    var path: String {
        switch self {
        case .tos:    return "/documents/pdf/tos"
        case .privacy:    return "/documents/pdf/privacy"
        case .herringPrivacy:    return "/documents/pdf/herring-privacy"
        case .cardholderAgreement:    return "/documents/pdf/cardholder-agreement"
        }
    }
    
    // MARK: - HTTP Method
    var method: HTTPMethod { .PUT }
    
    // MARK: - Header Configure
    var headerType: HeaderType { [.session, .movoInfo, .officeId] }
    
    // MARK: - Query Items
    var queryItems: [URLQueryItem]? { nil }
    
    // MARK: - Body
    
    var body: Data? {
        get throws {
            switch self {
            case .tos:
                return try JSONEncoder().encode(UserActionRequest(userAction: "GET-TOS-DATA"))
            case .privacy:
                return try JSONEncoder().encode(UserActionRequest(userAction: "GET-PRIVACY-DATA"))
            case .herringPrivacy:
                return try JSONEncoder().encode(UserActionRequest(userAction: "GET-HERRING-PRIVACY-DATA"))
            case .cardholderAgreement:
                return try JSONEncoder().encode(UserActionRequest(userAction: "GET-HERRING-CARD-AGREEMENT-DATA"))
            }
        }
    }
}
