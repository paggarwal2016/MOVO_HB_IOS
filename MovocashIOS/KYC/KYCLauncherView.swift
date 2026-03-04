//
//  KYCVerificationScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 04/03/26.
//

import SwiftUI

struct KYCLauncherView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        Color.clear
            .task {
                await startKYC()
            }
    }
    
    @MainActor
    private func startKYC() async {
        do {
            // Start KYC and wait for result
            let user = try await KYCManager.shared.start()
            print("KYC Success:", user)
            //TODO: OSCAR Implementation
            appState.flow = .home
        } catch let error as KYCError {
            appState.flow = .getStartedPhone
            AlertManager.shared.showError(error.localizedDescription)
        } catch {
            appState.flow = .getStartedPhone
            AlertManager.shared.showError(error.localizedDescription)
        }
    }
}
