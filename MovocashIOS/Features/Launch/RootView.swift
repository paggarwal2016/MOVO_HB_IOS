//
//  RootView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM = AppContainer.shared.makeAuthViewModel()
    
    var body: some View {
        NavigationStack {
            switch appState.flow {
            case .splash:
                SplashScreen()
            case .choice:
                ChoiceScreen()
            case .loginPhone:
                PhoneNumberScreen(flowType: .login)
            case .getStartedPhone:
                PhoneNumberScreen(flowType: .getStarted)
            case .otp:
                OTPScreen(authVM: authVM)
            case .kyc:
                KYCLauncherView()
            case .home:
                HomeTabBarView()
            }
        }
        .environmentObject(authVM)
        .animation(.easeInOut, value: appState.flow)
    }
}
