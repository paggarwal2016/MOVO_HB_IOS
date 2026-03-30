//
//  AppState.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI
import Combine

enum AuthFlow {
    case splash, choice, loginPhone, getStartedPhone, otp, setupPasscode, enableBiometrics, kyc, home
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
}
