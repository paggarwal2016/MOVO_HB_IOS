//
//  AppContainer.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import Combine

final class AppContainer: ObservableObject {

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    let authManager: AuthManagerProtocol
    let alertManager: AlertManagerProtocol
    let kycManager: KYCManagerProtocol
    let sessionManager: SessionManager
    let lockManager: AppLockManager
    let analytics: AnalyticsTracking

    init() {
        keychain = KeychainManager.shared
        authManager = AuthManager.shared
        alertManager = AlertManager.shared
        network = NetworkService.shared
        kycManager = KYCManager.shared
        analytics = AnalyticsManager.shared
        lockManager = AppLockManager(
            passcodeManager: PasscodeManager(),
            biometricManager: BiometricManager()
        )
        sessionManager = SessionManager(
            authManager: authManager,
            keychain: keychain,
            kycManager: kycManager,
            alertManager: alertManager,
            analytics: analytics
        )
    }

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            network: network,
            keychain: keychain,
            authManager: authManager,
            sessionManager: sessionManager,
            kycManager: kycManager,
            alertManager: alertManager,
            analytics: analytics
        )
    }

    func makeAppLockViewModel() -> AppLockViewModel {
        AppLockViewModel(lockManager: lockManager)
    }

    func makeVCardViewModel() -> VCardViewModel {
        VCardViewModel(network: network, alertManager: alertManager)
    }

    func makeSavingsAccountViewModel() -> SavingsAccountViewModel {
        SavingsAccountViewModel(network: network, alertManager: alertManager)
    }
    
    func makeTransactionViewModel() -> TransactionViewModel {
        TransactionViewModel(network: network, alertManager: alertManager)
    }
    
    func makeUserViewModel() -> UserViewModel {
        UserViewModel(network: network, alertManager: alertManager, analytics: analytics)
    }

    func makeKYCViewModel() -> KYCViewModel {
        KYCViewModel(kycManager: kycManager, alertManager: alertManager, analytics: analytics)
    }

}
