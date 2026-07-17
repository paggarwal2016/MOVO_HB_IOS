//
//  MovocashIOSApp.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI
import UIKit

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
    @Environment(\.scenePhase) private var scenePhase
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
                .logAppLifecycle(appState)
                .task {
                    await runPostBootstrap()
                }
            
                .onChangeCompat(of: scenePhase) { phase in
                    switch phase {
                    case .background:
                        recordBackgroundedScreen()
                    case .active:
                        resumeSplashIfNeeded()
                    default:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification
                )) { _ in
                    recordBackgroundedScreen()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.protectedDataWillBecomeUnavailableNotification
                )) { _ in
                    recordBackgroundedScreen()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )) { _ in
                    resumeSplashIfNeeded()
                }
        }
    }

    @MainActor
    private func recordBackgroundedScreen() {
        appState.backgroundedFlow = appState.flow
    }

    @MainActor
    private func resumeSplashIfNeeded() {
        guard appState.flow == .splash,
              !appState.hasCompletedBootstrap,
              appState.backgroundedFlow == .splash else { return }
        SecureLogger.info(
            "[Lifecycle] resumeSplashIfNeeded fired (warmupDone=\(appState.warmupCompleted)) — "
            + (appState.warmupCompleted ? "finalizing from cache" : "re-running warmup"),
            category: .auth
        )
        Task {
            if appState.warmupCompleted {
                await StartupRouter.finalizeNavigation(
                    appState: appState,
                    biometricAuthenticate: nil
                )
            } else {
                await runPostBootstrap()
            }
        }
    }

    @MainActor
    private func runPostBootstrap() async {
        await StartupRouter.postBootstrap(
            appState: appState,
            keychain: KeychainManager.shared,
            kycManager: container.kycManager,
            analytics: container.analytics,
            appConfigService: container.appConfigService,
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





