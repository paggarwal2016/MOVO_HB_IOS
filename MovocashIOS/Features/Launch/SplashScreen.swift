//
//  SplashScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct SplashScreen: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var lockupVisible = false
    @State private var attributionVisible = false
    @State private var didTransition = false
    
    public var brandColor: Color
    public var minimumDuration: TimeInterval
    public var onContinue: () -> Void
    
    public init(
        brandColor: Color = MovoLogoMark.brandSilver,
        minimumDuration: TimeInterval = 0.6,
        onContinue: @escaping () -> Void = {}
    ) {
        self.brandColor = brandColor
        self.minimumDuration = minimumDuration
        self.onContinue = onContinue
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            
            MovoBrandLockup(
                markSize: 120,
                wordmarkSize: 28,
                spacing: 28,
                color: .white,
                vertical: true
            )
            .scaleEffect(lockupVisible ? 1 : 0.96)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: handleAppear)
        .task {
            // Clear any stale mid-KYC flag from a previous session.
            UserDefaults.standard.removeObject(forKey: "kycInProgress")
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            let result = await sessionManager.restoreSession(appState: appState)
            
            switch result {
            case .restored:
                // ── Mid-onboarding guard ───────────────────────────────────────
                // kycCompleted is the authoritative signal that the user has
                // reached the dashboard at least once. If absent, the session was
                // killed during registration. Apply the fintech inactivity gate:
                // > 10 min idle → full logout; within window → restore last screen.
                guard UserDefaults.standard.bool(forKey: "kycCompleted") else {
                    let bgAt = UserDefaults.standard.double(forKey: "onboardingBackgroundedAt")
                    let elapsed: TimeInterval = bgAt > 0
                    ? Date().timeIntervalSince1970 - bgAt
                    : 0
                    UserDefaults.standard.removeObject(forKey: "onboardingBackgroundedAt")
                    
                    if elapsed >= AppState.onboardingInactivityTimeout {
                        await sessionManager.logout(appState: appState)
                        return
                    }
                    
                    if let raw = UserDefaults.standard.string(forKey: "onboardingLastScreen"),
                       let savedFlow = AuthFlow(rawValue: raw) {
                        if let ctxRaw = UserDefaults.standard.string(forKey: "onboardingContext") {
                            appState.context = PhoneFlowType(rawValue: ctxRaw)
                        }
                        // AppLockManager.init() sets state = .locked whenever isPasscodeSet,
                        // regardless of onboarding state. Clear it here — valid JWT tokens are
                        // proof of identity. Without this, the lock overlay fires the moment
                        // kycCompleted becomes true after KYC completes.
                        lockManager.resetToUnlocked()
                        appState.flow = savedFlow
                    } else {
                        // No restorable screen — ambiguous state, force re-auth.
                        await sessionManager.logout(appState: appState)
                    }
                    return
                }
                
                // ── Post-dashboard returning user ──────────────────────────────
                // Passcode confirmed — sync UserDefaults in case it was wiped by a reinstall.
                UserDefaults.standard.set(true, forKey: "kycCompleted")
                
                // Keychain-backed passcode is the authoritative "setup complete" indicator.
                // UserDefaults (kycCompleted) is cleared on reinstall but the Keychain persists,
                // so we trust the passcode presence over the UserDefaults flag.
                guard lockManager.isPasscodeSet else {
                    // Passcode was cleared (e.g. after a lockout reset) but tokens still exist.
                    // If RSA keys are present the server identity is intact — authenticate
                    // via biometrics and go directly home. No PIN fallback is available so
                    // a failed biometric clears the session and returns to the start.
                    guard RSAKeyManager.shared.keysExist() else {
                        await sessionManager.logout(appState: appState)
                        appState.flow = .choice
                        return
                    }
#if targetEnvironment(simulator)
                    // Simulator: loginWithBiometric blocks on a network call + a Face ID
                    // dialog that only responds to Hardware > Face ID menu.
                    // Go to ChoiceScreen without logging out — session is intact and
                    // the "Sign in with Face ID" button there lets the user trigger it manually.
                    appState.flow = .choice
#else
                    let success = await authVM.loginWithBiometric(appState: appState)
                    if !success {
                        // Session preserved — user can retry biometric from Choice screen
                        appState.flow = .choice
                    }
                    // On success: loginWithBiometric already sets appState.flow = .home
#endif
                    return
                }
                
                lockManager.evaluateOnLaunch()
                
#if targetEnvironment(simulator)
                // Simulator: skip automatic biometric during splash.
                // loginWithBiometric requires a live network call + Face ID via the
                // Hardware menu, which blocks splash indefinitely and prevents the
                // PIN screen from appearing. Go straight to PIN; the biometric button
                // in AppLockView lets the user trigger Face ID manually if desired.
                appState.flow = .appLock
#else
                // Trigger biometric while the splash is still on screen.
                // Face ID prompt appears over the splash — no intermediate screen shown.
                if lockManager.isBiometricEnabled || RSAKeyManager.shared.keysExist() {
                    let success = await authVM.loginWithBiometric(appState: appState)
                    if success {
                        lockManager.unlockAfterRSAAuth()
                        // loginWithBiometric already set appState.flow = .home
                        return
                    }
                }
                
                // Biometric not enrolled, failed, or cancelled → show PIN screen.
                // autoTriggerBiometric is false so Face ID is not re-prompted automatically.
                appState.flow = .appLock
#endif
                
            case .keychainLocked:
                ToastManager.shared.show(
                    "Your session could not be restored. Please unlock your device and try again.",
                    style: .error,
                    position: .bottom
                )
                appState.flow = .choice
                
            case .notLoggedIn:
                appState.flow = .choice
            }
        }
    }
    
    // MARK: - Lifecycle
    
    private func handleAppear() {
        withAnimation(.easeOut(duration: 0.6)) {
            lockupVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            attributionVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDuration) {
            guard !didTransition else { return }
            didTransition = true
            onContinue()
        }
    }
}
