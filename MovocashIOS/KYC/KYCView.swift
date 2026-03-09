//
//  KYCVerificationScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct KYCView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var kycVM = AppContainer.shared.makeKYCViewModel()

    var body: some View {
        Color.clear
            .task {
                await kycVM.startVerification(appState: appState)
            }
    }
}
