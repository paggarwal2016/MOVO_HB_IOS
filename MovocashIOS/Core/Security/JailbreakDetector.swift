//
//  JailbreakDetector.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import UIKit
import MachO

actor JailbreakDetector {
    static let shared = JailbreakDetector()
    private init() {}
    
    var isJailBroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return checkFileSystem()
        || checkSuspiciousFiles()
        || canWriteOutsideSandbox()
        || checkDyld()
        #endif
    }
        
    private func checkFileSystem() -> Bool {
        FileManager.default.fileExists(atPath: "/Applications/Cydia.app")
    }
    
    private func checkSuspiciousFiles() -> Bool {
        let suspiciousPaths = [
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
                        "/bin/bash",
                        "/usr/sbin/sshd",
                        "/etc/apt"
        ]
        
        return suspiciousPaths.contains { FileManager.default.fileExists(atPath: $0)}
    }
    
    private func canWriteOutsideSandbox() -> Bool {
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    private func checkDyld() -> Bool {
        let suspiciousLibraries = [
            "FridaGadget",
            "MobileSubstrate"
        ]

        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                if suspiciousLibraries.contains(where: { name.contains($0) }) {
                    return true
                }
            }
        }

        return false
    }
}

// TODO: - used App Launch

//if JailbreakDetector.shared.isJailbroken {
//    fatalError("Jailbroken device detected.")
//}
