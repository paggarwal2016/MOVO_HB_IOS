//
//  KYCVerificationScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct KYCView: View {
    
    @EnvironmentObject var appState: AppState
    
    private let kycManager = AppContainer.shared.kycManager
    private let alertManager = AppContainer.shared.alertManager
    
    var body: some View {
        Color.clear
            .task {
                do {
                    _ = try await kycManager.start()
                    appState.flow = .home
                } catch {
                    appState.flow = .getStartedPhone
                    alertManager.showError(error.localizedDescription)
                }
            }
    }
}
