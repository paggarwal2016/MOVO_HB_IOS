//
//  Environment.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//
import Foundation

enum Environment {
    case qa
    case production

    var baseURL: URL {
        switch self {
        case .qa:
            return URL(string: "https://api.mobile-banking-qa.herringbank.com")!
        case .production:
            return URL(string: "https://api.mobile-banking.herringbank.com")!
        }
    }
}
