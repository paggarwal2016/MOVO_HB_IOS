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
        let urlString: String
        
        switch self {
        case .qa:
            urlString = "https://api.mobile-banking-qa.herringbank.com"
        case .production:
            urlString = "https://api.mobile-banking.herringbank.com"
        }

        guard let url = URL(string: urlString) else {
            // These are hardcoded compile-time strings — failure is a developer error, not a runtime condition.
            preconditionFailure("Invalid baseURL configuration: \(urlString)")
        }

        return url
    }
}
