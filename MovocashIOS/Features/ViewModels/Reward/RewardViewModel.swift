//
//  RewardViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 24/03/26.
//

import Foundation
import Combine

@MainActor
final class RewardViewModel: BaseViewModel {
    
    private let network: NetworkServiceProtocol
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Reward get
    
    func getReward() async throws -> RewardResponse {
        let response: RewardResponse = try await perform { try await self.network.request(RewardAPI.getReward) }
        return response
    }
    
    // MARK: - Reward post
    
    func postReward() async throws -> RewardResponse {
        let response: RewardResponse =  try await perform { try await self.network.request(RewardAPI.postReward) }
        return response
    }
    
    // MARK: - Reward post Enroll
    
    func getEnrollReward() async throws -> RewardResponse {
        let response: RewardResponse =  try await perform { try await self.network.request(RewardAPI.enrollReward) }
        return response
    }
}
