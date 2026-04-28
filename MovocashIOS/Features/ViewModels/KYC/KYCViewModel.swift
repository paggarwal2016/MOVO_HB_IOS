//
//  KYCViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 06/03/26.
//

import Foundation
import Combine
import MobileBankingSDK

@MainActor
final class KYCViewModel: ObservableObject {

    private let kycManager: KYCManagerProtocol
    private let alertManager: AlertManagerProtocol
    private let analytics: AnalyticsTracking
    private let network: NetworkServiceProtocol

    init(
        kycManager: KYCManagerProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking,
        network: NetworkServiceProtocol
    ) {
        self.kycManager   = kycManager
        self.alertManager = alertManager
        self.analytics    = analytics
        self.network      = network
    }

    // MARK: - Start Verification

    func startVerification(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) async {
        analytics.trackKYCStarted()
        do {
            try await kycManager.configureSDK(officeId: AppConfig.officeId)
            let user = try await kycManager.start()
            Task { await saveUser(user) }
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

    // MARK: - Save User

    private func saveUser(_ user: User) async {
        let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        let request = SaveUserRequest(
            customerId:              user.customerId,
            firstName:               user.firstName,
            lastName:                user.lastName,
            username:                user.username,
            email:                   user.email,
            phone:                   user.phone,
            addressLine1:            user.addressLine1,
            addressLine2:            user.addressLine2,
            city:                    user.city,
            state:                   user.state,
            zip:                     user.zip,
            profilePicture:          user.profilePicture,
            isDeactivated:           user.isDeactivated,
            smsVerified:             user.smsVerified,
            smsVerifiedDate:         user.smsVerifiedDate,
            emailVerified:           user.emailVerified,
            cipAllowed:              user.cipAllowed,
            cipRequired:             user.cipRequired,
            isAdditionalKycRequired: user.isAdditionalKycRequired ?? false,
            isPlaidAuthRequired:     user.isPlaidAuthRequired,
            isTwoFactorEnabled:      user.isTwoFactorEnabled ?? false,
            fcmToken:                fcmToken,
            userAction:              "SAVE-USER-DATA"
        )
        do {
            let _: SuccessResponse = try await network.request(UserAPI.saveUser(request: request))
            SecureLogger.info("User data saved successfully after KYC", category: .network)
        } catch {
            SecureLogger.error("saveUser failed: \(error.localizedDescription)", category: .network)
        }
    }
}
