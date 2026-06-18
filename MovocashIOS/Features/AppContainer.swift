//
//  AppContainer.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import Combine

@MainActor
final class PrimaryCardStore: ObservableObject {
    @Published private(set) var card: VCardListResponse?
    func update(_ card: VCardListResponse?) {
        guard card != self.card else { return }
        self.card = card
    }
}

final class AppContainer: ObservableObject {

    let primaryCardStore = PrimaryCardStore()
    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    let alertManager: AlertManagerProtocol
    let kycManager: KYCManagerProtocol
    let sessionManager: SessionManager
    let lockManager: AppLockManager
    let analytics: AnalyticsTracking

    init() {
        keychain = KeychainManager.shared
        alertManager = AlertManager.shared
        network = NetworkService.shared
        kycManager = KYCManager.shared
        analytics = AnalyticsManager.shared
        lockManager = AppLockManager(
            passcodeManager: PasscodeManager(),
            biometricManager: BiometricManager()
        )
        sessionManager = SessionManager(
            keychain: keychain,
            kycManager: kycManager,
            alertManager: alertManager,
            analytics: analytics,
            network: network
        )
    }

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            network: network,
            keychain: keychain,
            sessionManager: sessionManager,
            kycManager: kycManager,
            alertManager: alertManager,
            analytics: analytics,
            lockManager: lockManager
        )
    }

    func makeAppLockViewModel() -> AppLockViewModel {
        AppLockViewModel(lockManager: lockManager)
    }

    func makeVCardViewModel() -> VCardViewModel {
        VCardViewModel(network: network, alertManager: alertManager, primaryCardStore: primaryCardStore)
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
        KYCViewModel(kycManager: kycManager, alertManager: alertManager, analytics: analytics, network: network)
    }
    
    func makePlaidACHViewModel() -> PlaidAchViewModel {
        PlaidAchViewModel(
            service: .shared,
            plaidLinkManager: PlaidLinkManager(network: network, keychain: keychain)
        )
    }

    func makeACHViewModel() -> ACHViewModel {
        ACHViewModel(network: network, alertManager: alertManager)
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(network: network, alertManager: alertManager, primaryCardStore: primaryCardStore)
    }

    func makePDFViewModel() -> PDFViewModel {
        PDFViewModel(network: network, alertManager: alertManager, analytics: analytics)
    }

    func makeContactViewModel() -> ContactViewModel {
        ContactViewModel(
            service: ContactsService(),
            network: network,
            alertManager: alertManager
        )
    }

}
