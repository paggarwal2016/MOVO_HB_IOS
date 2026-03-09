//
//  KYCVerificationScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct KYCLauncherView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var kycVM: KYCViewModel

    var body: some View {
        Color.clear
            .task {
                await kycVM.startVerification(appState: appState)
            }
    }
}
