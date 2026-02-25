//
//  DeviceManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import UIKit

final class DeviceManager {
    static let shared = DeviceManager()
    
    var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
}
