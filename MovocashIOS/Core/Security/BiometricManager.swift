//
//  BiometricManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import LocalAuthentication

protocol BiometricService {
    var isAvailable: Bool { get }
    var biometryType: LABiometryType { get }
    func authenticate(reason: String) async throws -> Bool
}

final class BiometricManager: BiometricService {
    
    static let shared = BiometricManager()
    
    private init() {}
    
    // MARK: - Check if biometric available
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &error
        )
    }
    
    // MARK: - Detect FaceID / TouchID
    var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return .none
        }
        
        return context.biometryType
    }
    
    // MARK: - Authenticate
    func authenticate(reason: String) async throws -> Bool {
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &error
        ) else {
            throw error ?? LAError(.biometryNotAvailable)
        }
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
    }
}
