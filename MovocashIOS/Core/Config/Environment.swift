//
//  Environment.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

// MARK: - Environment Type
enum AppEnvironmentType {
    case production
    case staging
    case dev

    var baseURLString: String {
        switch self {
        case .production: return "https://api.movo.money"
        case .staging:    return "https://api-staging.movocash.com"
        case .dev:        return "https://api.dev.movo.money"
        }
    }

    var sdkURLString: String {
        switch self {
        case .production, .staging, .dev:
            return "https://api.qa.herringbank.com"
        }
    }
}

// MARK: - AppEnvironment
struct AppEnvironment {
    private init() {}
    static let current: AppEnvironmentType = .staging // 🔁 Switch the Environment
    static let baseURL: URL   = makeURL(current.baseURLString)
    static let sdkURL: String = current.sdkURLString

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
    
    static let baseURL: URL    = AppEnvironment.baseURL
    static let sdkURL: String  = AppEnvironment.sdkURL
    static let officeId: String = "3"
    
    /// When `true`, protection is applied automatically:
    /// When `false`, all of the above is disabled — screenshots and screen
    static let isScreenProtectionEnabled: Bool = false
}
