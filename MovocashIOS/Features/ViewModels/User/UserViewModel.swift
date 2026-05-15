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

    // MARK: - Fetch Profile (initial load — uses perform() for loading state)

    func fetchProfile() async {
        do {
            let response: UserProfileAPIResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(UserAPI.getProfile)
            }
            profile = response.data
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

    // Pull-to-refresh — bypasses perform() so state stays idle,
    // preventing view re-renders that cancel the refreshable task.
    func refresh() async {
        do {
            let response: UserProfileAPIResponse = try await network.request(UserAPI.getProfile)
            profile = response.data
        } catch is CancellationError {
            // User dismissed the pull gesture — keep existing data silently
        } catch {
            if error.shouldShowUserFacingToast {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
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
