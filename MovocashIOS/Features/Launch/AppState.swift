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

enum NetworkStatus {
    case connected, disconnected
}

@MainActor
final class AppState: ObservableObject {
    @Published var flow: AuthFlow = .splash
    @Published var context: String = ""
    @Published var otpVerified: Bool = false
    @Published var kycVerified: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var networkStatus: NetworkStatus = .connected
}
