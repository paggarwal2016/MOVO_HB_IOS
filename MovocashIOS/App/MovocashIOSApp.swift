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
    @StateObject private var kycVM: KYCViewModel
    @StateObject private var pushManager: PushManager
    init() {
        let c = AppContainer()
        let state = AppState()

        // App.init isn't formally @MainActor, but SwiftUI runs it on main.
        // assumeIsolated is the canonical Swift pattern to call @MainActor code
        // from an init that's de-facto-but-not-statically on the main actor.
        MainActor.assumeIsolated {
            StartupRouter.bootstrap(
                appState: state,
                keychain: KeychainManager.shared,
                lockManager: c.lockManager
            )
        }

        _appState         = StateObject(wrappedValue: state)
        _container        = StateObject(wrappedValue: c)
        _lockManager      = StateObject(wrappedValue: c.lockManager)
        _authVM           = StateObject(wrappedValue: c.makeAuthViewModel())
        _userVM           = StateObject(wrappedValue: c.makeUserViewModel())
        _lockVM           = StateObject(wrappedValue: c.makeAppLockViewModel())
        _kycVM            = StateObject(wrappedValue: c.makeKYCViewModel())
        _pushManager      = StateObject(wrappedValue: PushManager.shared)
        TabBarAppearance.configure()
        UIRefreshControl.appearance().tintColor = DesignTokens.Palette.accent.uiColor
    }

    var body: some Scene {
        WindowGroup {
            RootView(kycVM: kycVM)
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
                .task {
                    await StartupRouter.postBootstrap(
                        appState: appState,
                        keychain: KeychainManager.shared,
                        kycManager: container.kycManager,
                        analytics: container.analytics,
                        biometricAuthenticate: {
                            #if targetEnvironment(simulator)
                            return false
                            #else
                            return await authVM.loginWithBiometric(appState: appState)
                            #endif
                        }
                    )
                }
        }
    }
}





