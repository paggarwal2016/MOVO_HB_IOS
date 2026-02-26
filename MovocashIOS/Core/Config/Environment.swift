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
    
    var baseURLString: String {
        switch self {
        case .qa:
            return "https://api.mobile-banking-qa.herringbank.com"
        case .production:
            return "https://api.mobile-banking.herringbank.com" // TODO: - AI info - Provide Correct production url
        }
    }
}
