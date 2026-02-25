//
//  BiometricManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/02/26.
//

import LocalAuthentication

struct BiometricManager {

    static var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?

        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        return canEvaluate
    }

    static var type: LABiometryType {
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
}
