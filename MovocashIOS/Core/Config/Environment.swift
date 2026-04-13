//
//  Environment.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

// MARK: - Environment
struct Environment {
    private init() {}
    
    static let baseURL: URL = makeURL("https://api-staging.movocash.com") // SP URL
    static let sdkURL: String = "https://api.qa.herringbank.com"          // SDK URL
    
    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            assertionFailure("Invalid URL configuration: \(string)")
            return URL(fileURLWithPath: "/")
        }
        return url
    }
}

// MARK: - API Version

enum APIVersion: String {
    case v1 = "v1"
}



// MARK: - AppConfig
final class AppConfig {
    private init() {}
    
    static let baseURL: URL    = Environment.baseURL
    static let sdkURL: String  = Environment.sdkURL
    static let officeId: String = "3"
}


