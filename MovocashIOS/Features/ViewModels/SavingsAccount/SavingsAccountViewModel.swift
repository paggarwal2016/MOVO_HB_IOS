//
//  SavingsAccountViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import Combine

@MainActor
final class SavingsAccountViewModel: BaseViewModel {
    
    // MARK: - Dependencies
    
    private let network: NetworkServiceProtocol
    
    // MARK: - Init
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Get List
    
    func getSavingAccountList() async throws -> SavingsAccountListResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.list)
        }
    }

    // MARK: - Create Account
    
    func createSavingAccount(request: SavingsAccountRequest.CreateAccount) async throws -> SavingsAccountDetailsResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.create(request))
        }
    }
    
    // MARK: - Update Account
    
    func updateSavingAccount(request: SavingsAccountRequest.UpdateAccount) async throws -> SuccessResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.update(request))
        }
    }
    
    // MARK: - Delete Account
    
    func deleteSavingAccount(request: SavingsAccountRequest.DeleteAccount) async throws -> SuccessResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.delete(request))
        }
    }
        
    // MARK: - Account Details
    
    func getSavingAccountDetails(accountID: Int) async throws -> SavingsAccountDetailsResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.details(accountId: accountID))
        }
    }
}
