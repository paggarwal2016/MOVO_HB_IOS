//
//  AppInfo.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import UIKit

enum AppInfo {
    
    nonisolated static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.0.0"
    }
    
    nonisolated static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    nonisolated static var fullVersion: String {
        "\(version) (\(buildNumber))"
    }
    
    nonisolated static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }
    
    static var osVersion: String {
        UIDevice.current.systemVersion
    }
    
    static let applicationName: String = "movo-ios"
    
    static var platform: String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "unknown"
        #endif
    }    
}
