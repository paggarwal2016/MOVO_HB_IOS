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

    // MARK: - Published State

    @Published var accountList: SavingsAccountListResponse?
    @Published var accountDetail: SavingsAccountDetailsResponse?

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    
    // MARK: - Init
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Load Accounts

    func loadAccounts() async {
        do {
            accountList = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(SavingsAccountAPI.list())
            }
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Update Nickname

    func updateNickname(name: String, accountId: Int) async {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(
                    SavingsAccountAPI.update(SavingsAccountRequest.UpdateAccount(nickname: name, accountId: accountId))
                )
            }
            await loadAccounts()
            ToastManager.shared.show("Nickname updated!", style: .success, position: .bottom)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            ToastManager.shared.show("Failed to update nickname.", style: .error, position: .bottom)
        }
    }

    // MARK: - Create Account

    func createAccount(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            ToastManager.shared.show("Account name cannot be empty.", style: .error, position: .bottom)
            return
        }
        do {
            let _: SavingsAccountDetailsResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(
                    SavingsAccountAPI.create(SavingsAccountRequest.CreateAccount(nickname: trimmed))
                )
            }
            await loadAccounts()
            ToastManager.shared.show("\"\(trimmed)\" account created!", style: .success, position: .bottom)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            ToastManager.shared.show("Failed to create account. Please try again.", style: .error, position: .bottom)
        }
    }

    // MARK: - Get List

    func getSavingAccountList(
        sortBy: SavingsSortBy? = nil,
        sortDirection: SavingsSortDirection? = nil
    ) async throws -> SavingsAccountListResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.list(sortBy: sortBy, sortDirection: sortDirection))
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

    func loadAccountDetail(accountID: Int) async {
        do {
            accountDetail = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(SavingsAccountAPI.details(accountId: accountID))
            }
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            ToastManager.shared.show("Failed to load account details.", style: .error, position: .bottom)
        }
    }
}
