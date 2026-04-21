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
    private let analytics: AnalyticsTracking

    init(
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking
    ) {
        self.kycManager = kycManager
        self.alertManager = alertManager
        self.analytics = analytics
    }

    // MARK: - Start Verification

    func startVerification(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) async {
        analytics.trackKYCStarted()
        do {
            try await kycManager.start()
            analytics.trackKYCCompleted(step: .idVerified)
            onSuccess()
        } catch _ as KYCError {
            analytics.trackKYCAbandoned(step: .idVerified)
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        } catch {
            analytics.trackKYCAbandoned(step: .idVerified)
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        }
    }
}
