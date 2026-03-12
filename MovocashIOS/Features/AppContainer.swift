//
//  AppContainer.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

final class AppContainer {

    static let shared = AppContainer()

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    let authManager: AuthManagerProtocol
    let alertManager: AlertManagerProtocol
    let kycManager: KYCManagerProtocol
    let sessionManager: SessionManager
    
    static let lockManager: AppLockManager = {
        AppLockManager(
            passcodeManager: PasscodeManager(),
            biometricManager: BiometricManager()
        )
    }()


    init() {
        keychain = KeychainManager.shared
        authManager = AuthManager.shared
        alertManager = AlertManager.shared
        network = NetworkService.shared
        kycManager = KYCManager.shared
        sessionManager = SessionManager(
            authManager: authManager,
            keychain: keychain,
            kycManager: kycManager,
            alertManager: alertManager
        )
    }

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            network: network,
            keychain: keychain,
            authManager: authManager,
            sessionManager: sessionManager,
            kycManager: kycManager,
            alertManager: alertManager
        )
    }
    
    func makeAppLockViewModel() -> AppLockViewModel {
        AppLockViewModel(lockManager: AppContainer.lockManager)
    }
}
