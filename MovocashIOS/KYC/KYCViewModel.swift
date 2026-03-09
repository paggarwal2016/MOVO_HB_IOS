//
//  KYCViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation

@MainActor
final class KYCViewModel: ObservableObject {

    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol

    init(kycManager: KYCManagerProtocol, alertManager: AlertManagerProtocol) {
        self.kycManager = kycManager
        self.alertManager = alertManager
    }

    // MARK: - Start Verification

    func startVerification(appState: AppState) async {
        do {
            _ = try await kycManager.start()
            //TODO: OSCAR Implementation
            appState.flow = .home
        } catch let error as KYCError {
            appState.flow = .getStartedPhone
            alertManager.showError(error.localizedDescription)
        } catch {
            appState.flow = .getStartedPhone
            alertManager.showError(error.localizedDescription)
        }
    }
}
