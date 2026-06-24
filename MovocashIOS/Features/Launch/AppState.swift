//
//  AppState.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI
import Combine

enum AuthFlow: String {
    case splash, choice, loginPhone, getStartedPhone, otp, signupDetails, emailVerification, getStartedInfo, enableBiometrics, pickDocument, kyc, kycSuccess, appLock, warmRelock, home
}

enum PhoneFlowType: String {
    case login = "login"
    case getStarted = "registration"
}

enum NetworkStatus {
    case connected, disconnected
}

@MainActor
final class AppState: ObservableObject {
    @Published var flow: AuthFlow = .splash
    @Published var context: PhoneFlowType?
    @Published var otpVerified: Bool = false
    @Published var kycVerified: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var networkStatus: NetworkStatus = .connected
    /// Set to true when a new user completes KYC and is arriving at home for the
    /// first time. Cleared by HomeTabBarView.onAppear once the home screen is live.
    @Published var isNewRegistration: Bool = false

    /// Changes whenever protected navigation (home tabs, nested stacks, sheets) must be
    /// torn down — e.g. session expiry — so SwiftUI rebuilds a fresh shell.
    @Published private(set) var protectedShellID = UUID()

    // NEW — destination decided at boot, applied after splash min-duration
    var pendingDestination: AuthFlow?
    var pendingContext: PhoneFlowType?

    /// True when the app cold-launched directly into the KYC step (Pick Document) because
    /// the camera permission was just granted in Settings (iOS force-relaunches for that).
    /// There is no Get Started Info screen behind it in this launch, so Pick Document's
    /// Back must exit to Choice instead.
    var kycStepResumed = false

    /// Fintech-standard inactivity window for the pre-dashboard onboarding flow.
    /// Exceeding this triggers a full logout so no partial session can be resumed.
    static let onboardingInactivityTimeout: TimeInterval = 600 // 10 minutes

    /// Matches server-side API idle timeout. Used by StartupRouter to skip
    /// AppLock for PIN-only users when the server session is certainly dead.
    static let apiIdleTimeout: TimeInterval = 15 * 60

    // NEW — minimum splash duration for visual stability
    static let splashMinDuration: TimeInterval = 0.8

    /// One-shot guard so post-bootstrap warmup cannot re-run if RootView's .task re-fires.
    var hasCompletedBootstrap = false

    func invalidateProtectedShell() {
        protectedShellID = UUID()
    }
}
