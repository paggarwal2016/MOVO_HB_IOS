//
//  KYCVerificationScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct KYCView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var kycVM = AppContainer.shared.makeKYCViewModel()

    var body: some View {
        Color.clear
            .task {
                await kycVM.startVerification {
                    appState.isNewRegistration = true
                    appState.flow = .home
                } onFailure: {
                    //TODO: Future Implementation will check below code logic
                    Task {
                        AppContainer.lockManager.logout()
                        await sessionManager.logout(appState: appState)
                        appState.flow = .getStartedPhone
                    }
                }
            }
    }
}
