//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

@main
struct MovocashIOSApp: App {
    @StateObject private var appState: AppState
    @StateObject private var container: AppContainer
    @StateObject private var lockManager: AppLockManager
    @StateObject private var authVM: AuthViewModel
    @StateObject private var userVM: UserViewModel
    @StateObject private var lockVM: AppLockViewModel
    @StateObject private var passcodeSetupVM: AppLockViewModel

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
        TabBarAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(passcodeSetupVM: passcodeSetupVM)
                .preferredColorScheme(.light)
                .environmentObject(appState)
                .environmentObject(container)
                .environmentObject(lockManager)
                .environmentObject(authVM)
                .environmentObject(userVM)
                .environmentObject(lockVM)
                .environmentObject(container.sessionManager)
                .networkMonitor(state: appState)
                .globalToast()
                .globalAlert()
        }
    }
}
