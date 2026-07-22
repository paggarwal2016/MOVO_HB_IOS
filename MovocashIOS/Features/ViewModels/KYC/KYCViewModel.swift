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

            // Persist the verified user and WAIT for the Save User API success
            // acknowledgment before any further processing — only then do we mark
            // KYC complete and hand off via onSuccess. A full-screen spinner covers
            // the wait since the underlying `.kyc` flow renders nothing once the
            // scanner dismisses.
            SpinnerView.showFullScreen()
            let saved = await saveUser(user)
            SpinnerView.hideFullScreen()
            guard saved else {
                // saveUser() already emitted a precise `kyc_step_failed` event with
                // the underlying code/message, so no analytics call is needed here.
                alertManager.showError("We couldn't save your verification details. Please try again.")
                onFailure()
                return
            }

            analytics.trackKYCCompleted(step: .idVerified)
            onSuccess()
        } catch _ as KYCError {
            // User did not complete the scanner flow — genuine abandonment.
            analytics.trackKYCAbandoned(step: .idVerified)
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        } catch {
            // SDK/config failure — a real error, not user abandonment.
            analytics.trackKYCStepFailed(step: .idVerified, errorCode: error.analyticsCode, errorMessage: error.localizedDescription)
            alertManager.showError("Your KYC verification is not completed. Please complete verification to continue.")
            onFailure()
        }
    }

    // MARK: - Save User

    /// Saves the verified user. Returns `true` only when the request succeeds and the
    /// API doesn't explicitly acknowledge failure (`success == false`).
    @discardableResult
    private func saveUser(_ user: User) async -> Bool {
        let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        let request = SaveUserRequest(
            customerId:                 user.customerId,
            firstName:                  user.firstName,
            lastName:                   user.lastName,
            username:                   user.username,
            email:                      user.email,
            phone:                      user.phone,
            addressLine1:               user.addressLine1,
            addressLine2:               user.addressLine2,
            city:                       user.city,
            state:                      user.state,
            zip:                        user.zip,
            driversLicenseNumber:       user.driversLicenseNumber,
            driversLicenseExpiration:   user.driversLicenseExpiration,
            driversLicenseState:        user.driversLicenseState,
            profilePicture:             user.profilePicture,
            isDeactivated:              user.isDeactivated,
            smsVerified:                user.smsVerified,
            smsVerifiedDate:            user.smsVerifiedDate,
            emailVerified:              user.emailVerified,
            emailVerifiedDate:          user.emailVerifiedDate,
            cipAllowed:                 user.cipAllowed,
            cipRequired:                user.cipRequired,
            isAdditionalKycRequired:    user.isAdditionalKycRequired ?? false,
            isPlaidAuthRequired:        user.isPlaidAuthRequired,
            isTwoFactorEnabled:         user.isTwoFactorEnabled ?? false,
            tosAcceptedDate:            user.tosAcceptedDate,
            virtualCardTosAcceptedDate: user.virtualCardTosAcceptedDate,
            eDeliveryAcceptedDate:      user.eDeliveryAcceptedDate,
            fcmToken:                   fcmToken,
            userAction:                 "SAVE-USER-DATA"
        )
        do {
            let response: SuccessResponse = try await network.request(UserAPI.saveUser(request: request))
            guard response.success != false else {
                SecureLogger.error("saveUser returned success=false after KYC", category: .network)
                analytics.trackKYCStepFailed(step: .idVerified, errorCode: "server_rejected", errorMessage: nil)
                return false
            }
            SecureLogger.info("User data saved successfully after KYC", category: .network)
            analytics.log(AnalyticsEvent.kycUserSaved)
            return true
        } catch {
            SecureLogger.error("saveUser failed: \(error.localizedDescription)", category: .network)
            analytics.trackKYCStepFailed(step: .idVerified, errorCode: error.analyticsCode, errorMessage: error.localizedDescription)
            return false
        }
    }
}
