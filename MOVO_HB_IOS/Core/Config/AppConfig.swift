//
//  AppConfig.swift
//  MOVO_HB_IOS
//
//  Created by Movo Developer on 24/02/26.
//

import Foundation

final class AppConfig {
    
    #if DEBUG
    static let environment: Environment = .QA
    #else
    static let environment: Environment = .production
    #endif
    
    static var baseURL: URL {
        guard let url = URL(string: environment.baseURLString) else {
            fatalError("Invalid Base URL configuration")
        }
        return url
    }
}
