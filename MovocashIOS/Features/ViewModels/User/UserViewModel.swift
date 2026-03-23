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
    
    // MARK: - Init
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Get List
    
    func fetchProfile() async {
        do {
            profile = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(UserAPI.getProfile)
            }
        } catch is CancellationError {
            // Task was cancelled — no action needed
        } catch {
            // Error already surfaced via toast in BaseViewModel.perform
        }
    }
    
    // MARK: - Delete Account

    func deleteAccount() async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(UserAPI.deleteProfile)
            }
            profile = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }
}
