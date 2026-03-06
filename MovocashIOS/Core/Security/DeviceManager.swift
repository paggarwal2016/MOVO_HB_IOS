//
//  DeviceManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import UIKit

final class DeviceManager {
    
    static let shared = DeviceManager()
    
    private let keychain = KeychainManager.shared
    private let deviceKey = "device_id"
    
    private init() {}
    
    var deviceID: String {
        
        // Check if device ID already exists
        if let saved = try? keychain.get(deviceKey),
           !saved.isEmpty {
            return saved
        }
        
        // Use identifierForVendor
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            try? keychain.save(idfv, for: deviceKey, protection: .backgroundSafe)
            return idfv
        }
        
        // Generate fallback UUID
        let generated = UUID().uuidString
        try? keychain.save(generated, for: deviceKey, protection: .backgroundSafe)
        
        return generated
    }
}
