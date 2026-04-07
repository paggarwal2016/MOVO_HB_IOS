//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

@main
struct MovocashIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState: AppState
    @StateObject private var container: AppContainer
    @StateObject private var lockManager: AppLockManager
    @StateObject private var authVM: AuthViewModel
    @StateObject private var userVM: UserViewModel
    @StateObject private var lockVM: AppLockViewModel
    @StateObject private var passcodeSetupVM: AppLockViewModel
    @StateObject private var kycVM: KYCViewModel
    @StateObject private var pushManager: PushManager

    init() {
        let c = AppContainer()
        let setupVM = AppLockViewModel(lockManager: c.lockManager)
        setupVM.isSetupMode = true
        _appState         = StateObject(wrappedValue: AppState())
        _container        = StateObject(wrappedValue: c)
        _lockManager      = StateObject(wrappedValue: c.lockManager)
        _authVM           = StateObject(wrappedValue: c.makeAuthViewModel())
        _userVM           = StateObject(wrappedValue: c.makeUserViewModel())
        _lockVM           = StateObject(wrappedValue: c.makeAppLockViewModel())
        _passcodeSetupVM  = StateObject(wrappedValue: setupVM)
        _kycVM            = StateObject(wrappedValue: c.makeKYCViewModel())
        _pushManager      = StateObject(wrappedValue: PushManager.shared)
        TabBarAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(passcodeSetupVM: passcodeSetupVM, kycVM: kycVM)
                .preferredColorScheme(.light)
                .environmentObject(appState)
                .environmentObject(container)
                .environmentObject(lockManager)
                .environmentObject(authVM)
                .environmentObject(userVM)
                .environmentObject(lockVM)
                .environmentObject(container.sessionManager)
                .environmentObject(pushManager)
                .networkMonitor(state: appState)
                .globalToast()
                .globalAlert()
        }
    }
}





