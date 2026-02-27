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

    static var baseURL: URL {
        environment.baseURL
    }
}
