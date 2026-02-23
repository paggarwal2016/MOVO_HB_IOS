//
//  Environment.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//
import Foundation

enum Environment {
    case dev
    case staging
    case production
    
    var baseURL: URL {
        switch self {
        case .dev:
            return URL(string: "https://api.mobile-banking-qa.herringbank.com")!
        case .staging:
            return URL(string: "https://api.mobile-banking-qa.herringbank.com")!
        case .production:
            return URL(string: "https://api.mobile-banking-qa.herringbank.com")!
        }
    }
}
