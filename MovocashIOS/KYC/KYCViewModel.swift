//
//  KYCViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import Combine

@MainActor
final class KYCViewModel: ObservableObject {

    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol

    init(kycManager: KYCManagerProtocol, alertManager: AlertManagerProtocol) {
        self.kycManager = kycManager
        self.alertManager = alertManager
    }

    // MARK: - Start Verification

    func startVerification(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) async {
        do {
            _ = try await kycManager.start()
            onSuccess()
        } catch _ as KYCError {
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        } catch {
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        }
    }
}
