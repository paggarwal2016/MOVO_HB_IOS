//
//  RewardViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 24/03/26.
//

import Foundation
import Combine

@MainActor
final class RewardViewModel: BaseViewModel {
    
    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Reward get
    
    func getReward() async throws -> RewardResponse {
        do {
            let response: RewardResponse = try await perform { try await self.network.request(RewardAPI.getReward) }
            analytics.log(AnalyticsEvent.rewardViewed)
            return response
        } catch {
            analytics.log(AnalyticsEvent.rewardFetchFailed)
            throw error
        }
    }

    // MARK: - Reward post

    func postReward() async throws -> RewardResponse {
        do {
            let response: RewardResponse = try await perform { try await self.network.request(RewardAPI.postReward) }
            analytics.log(AnalyticsEvent.rewardRedeemed)
            return response
        } catch {
            analytics.log(AnalyticsEvent.rewardRedemptionFailed)
            throw error
        }
    }

    // MARK: - Reward post Enroll

    func getEnrollReward() async throws -> RewardResponse {
        do {
            let response: RewardResponse = try await perform { try await self.network.request(RewardAPI.enrollReward) }
            analytics.log(AnalyticsEvent.rewardEnrolled)
            return response
        } catch {
            analytics.log(AnalyticsEvent.rewardEnrollFailed)
            throw error
        }
    }
}
