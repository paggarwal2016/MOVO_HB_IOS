//
//  AppInfo.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation

enum AppInfo {
    
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var fullVersion: String {
        "\(version) (\(buildNumber))"
    }
    
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }
}
