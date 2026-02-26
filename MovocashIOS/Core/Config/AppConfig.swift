//
//  AppConfig.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import Foundation

final class AppConfig {

    #if DEBUG
    static let environment: Environment = .qa
    #else
    static let environment: Environment = .production
    #endif

    static func baseURL() throws -> URL {

        guard let url = URL(string: environment.baseURLString) else {
            #if DEBUG
            fatalError("❌ Invalid Base URL: \(environment.baseURLString)")
            #else
            throw AppConfigError.invalidBaseURL(environment.baseURLString)
            #endif
        }
        return url
    }
}


enum AppConfigError: LocalizedError {
    case invalidBaseURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url):
            return "Invalid server configuration: \(url)"
        }
    }
}
