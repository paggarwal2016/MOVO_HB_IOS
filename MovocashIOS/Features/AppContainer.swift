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

@MainActor
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

        // Reset the shared DashboardViewModel when any session-end path fires
        // (logout, 401 expiry, force logout). This lives here — not in
        // HomeTabBarView — because HomeTabBarView may already be tearing down
        // when the session ends and its view-modifier callbacks are unreliable.
        // onSessionEnd fires synchronously inside SessionManager.resetAppState,
        // before appState.flow transitions away from .home — so HomeTabBarView is
        // still alive when this runs. Handles the sync portion of push cleanup.
        // NOTE: push-state cleanup is split across two sites:
        //   • PushManager.messages/unreadCount/latestMessage — here (sync)
        //   • PushManager.fcmToken — async Task in SessionManager.handleSessionExpired
        // Both target PushManager.shared. See SessionManager.handleSessionExpired for
        // the async half.
        sessionManager.onSessionEnd = { @MainActor [weak self] in
            self?._dashboardViewModel?.reset()
            PushManager.shared.clearAll()
        }
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

    /// Single shared instance — survives HomeTabBarView recreations (biometric re-entry,
    /// onboarding → home transition). HomeTabBarView uses @ObservedObject, not @StateObject,
    /// so SwiftUI never resets this when the view is torn down and rebuilt.
    /// Optional so onSessionEnd never instantiates it spuriously (e.g. a 401 during
    /// onboarding before HomeTabBarView has ever mounted).
    private var _dashboardViewModel: DashboardViewModel?

    func makeDashboardViewModel() -> DashboardViewModel {
        if let existing = _dashboardViewModel { return existing }
        let vm = DashboardViewModel(network: network, alertManager: alertManager, primaryCardStore: primaryCardStore)
        _dashboardViewModel = vm
        return vm
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
