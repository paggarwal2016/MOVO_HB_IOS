//
//  UserViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation
import Combine

@MainActor
final class UserViewModel: BaseViewModel {

    @Published var profile: UserProfileResponse?

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking
    ) {
        self.network = network
        self.analytics = analytics
        super.init(alertManager: alertManager)
    }

    // MARK: - Fetch Profile

    func fetchProfile() async {
        do {
            profile = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(UserAPI.getProfile)
            }
            if let profile {
                analytics.log(AnalyticsEvent.accountViewed)
                analytics.setUserProperty(
                    profile.cipRequired ? "pending" : "verified",
                    for: UserPropertyKey.kycStatus
                )
                analytics.setUserProperty(
                    profile.isTwoFactorEnabled ? "true" : "false",
                    for: UserPropertyKey.biometricEnabled
                )
            }
        } catch is CancellationError {
            // Task was cancelled — no action needed
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(UserAPI.deleteProfile)
            }
            analytics.log(AnalyticsEvent.accountDeleted)
            profile = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
            return false
        }
    }
}
