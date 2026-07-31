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
        case .production:
            return "https://api.mobile-banking-prod.herringbank.com"
        case .staging, .dev:
            return "https://api.qa.herringbank.com"
        }
    }

    var officeId: String {
        switch self {
        case .production:       return "5"
        case .staging, .dev:    return "3"
        }
    }
    
    var cryptoKey: String {
        switch self {
        case .production:       return "kmFXWgS7Y3Hn2fnwG6EemF8gtkmLLySmrh4PloQH4gM="
        case .staging, .dev:    return "iWXqDFMh19wGaaloJs8SG7/aWNmJJx9JjkJ9Pgju8no="
        }
    }

    // MARK: - SSL Pinning
    var pinnedCertificateNames: String {
        switch self {
        case .dev:        return "dev-server"
        case .staging:    return ""
        case .production: return "prod-server"
        }
    }
}


// MARK: - AppEnvironment

struct AppEnvironment {
    private init() {}
    static let current: AppEnvironmentType = .dev // 🔁 Switch the Environment
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
    
    static let baseURL: URL      = AppEnvironment.baseURL
    static let sdkURL: String    = AppEnvironment.sdkURL
    static let officeId: String  = AppEnvironment.current.officeId
    static let cryptoKey: String = AppEnvironment.current.cryptoKey
   
    //MARK: - App security
    
    /// App screen protection screenshot / record
    static let isScreenProtectionEnabled: Bool = false

    /// SSL pinning enable
    static let isSSLPinningEnabled: Bool = false

    /// SSL pinning certificate name
    static let pinnedCertificateName: String   = AppEnvironment.current.pinnedCertificateNames
    
    //MARK: - Customer Support
    
    static let customerCare = "(866) 348-3435"

    static let customerCareNumber = "tel:+1\(customerCare.filter(\.isNumber))"
}
