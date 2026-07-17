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
    @StateObject private var idleTimer: IdleTimerManager = IdleTimerManager()
    init() {
        let c = AppContainer()
        let state = AppState()

        // Fresh-install wipe MUST precede bootstrap: bootstrap reads the Keychain to
        // decide routing, and on reinstall the Keychain still holds stale entries
        // (RSA key, per-user enrollment flags). Clearing first guarantees a reinstall
        // routes like a true first run instead of misrouting into a broken biometric
        // gate whose key is about to be wiped.
        AppDelegate.clearOnFreshInstallIfNeeded()

        // App.init isn't formally @MainActor, but SwiftUI runs it on main.
        // assumeIsolated is the canonical Swift pattern to call @MainActor code
        // from an init that's de-facto-but-not-statically on the main actor.
        MainActor.assumeIsolated {
            StartupRouter.bootstrap(
                appState: state,
                keychain: KeychainManager.shared,
                lockManager: c.lockManager
            )
            // Wire the cover-gate coordination closure. The cover-raiser calls this
            // at willEnterForeground to skip the auth cover when the lock gate is
            // already on screen (the gate is itself opaque; raising the cover above
            // it blocks the retry UI). Weak capture so AppLockManager never retains
            // AppState; nil flow degrades to false → cover raised, the safe direction.
            c.lockManager.isLockUIVisible = { [weak state] in
                state?.flow == .appLock || state?.flow == .warmRelock
            }
        }

        _appState         = StateObject(wrappedValue: state)
        _container        = StateObject(wrappedValue: c)
        _lockManager      = StateObject(wrappedValue: c.lockManager)
        _authVM           = StateObject(wrappedValue: c.makeAuthViewModel())
        _userVM           = StateObject(wrappedValue: c.makeUserViewModel())
        _lockVM           = StateObject(wrappedValue: c.makeAppLockViewModel())
        _kycVM            = StateObject(wrappedValue: c.makeKYCViewModel())
        _pushManager      = StateObject(wrappedValue: PushManager.shared)
        UIRefreshControl.appearance().tintColor = DesignTokens.Palette.accent.uiColor
    }

    var body: some Scene {
        WindowGroup {
            RootView(kycVM: kycVM)
                .environmentObject(appState)
                .environmentObject(container)
                .environmentObject(container.primaryCardStore)
                .environmentObject(lockManager)
                .environmentObject(authVM)
                .environmentObject(userVM)
                .environmentObject(lockVM)
                .environmentObject(container.sessionManager)
                .environmentObject(pushManager)
                .environmentObject(idleTimer)
                .networkMonitor(state: appState)
                .globalToast()
                .globalAlert()
                .sensitiveScreen() // Layer 2: shield during recording + app-switcher (whole app)
                .secured(forwardDismiss: false) // Layer 1: blank screenshots & recordings of the main hierarchy
                .task {
                    await StartupRouter.postBootstrap(
                        appState: appState,
                        keychain: KeychainManager.shared,
                        kycManager: container.kycManager,
                        analytics: container.analytics,
                        // Device-session config is fetched only during login (after OTP),
                        // so it is intentionally not warmed up at bootstrap anymore.
                        biometricAuthenticate: {
                            #if targetEnvironment(simulator)
                            return false
                            #else
                            return await authVM.loginWithBiometric(appState: appState, navigateOnSuccess: false)
                            #endif
                        }
                    )
                }
        }
    }
}





