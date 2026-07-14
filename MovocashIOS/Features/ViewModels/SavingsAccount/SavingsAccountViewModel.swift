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
    @Published var accountDetail: SavingsAccountInfo?

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Load Accounts

    func loadAccounts() async {
        do {
            accountList = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(SavingsAccountAPI.list())
            }
            analytics.log(AnalyticsEvent.savingsAccountListViewed)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            analytics.log(AnalyticsEvent.savingsAccountListFailed, params: [
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Update Nickname

    func updateNickname(name: String, accountId: Int, primaryAccountId: Int) async {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(
                    SavingsAccountAPI.update(SavingsAccountRequest.UpdateAccount(nickname: name, accountId: accountId, primaryAccountId: primaryAccountId, userAction: "UPDATE-ACCOUNT-NICKNAME"))
                )
            }
            analytics.log(AnalyticsEvent.savingsNicknameUpdated, params: [
                AnalyticsParam.accountId: accountId
            ])
            //await loadAccounts()
            ToastManager.shared.show("Nickname updated!", style: .success, position: .bottom)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            analytics.log(AnalyticsEvent.savingsNicknameUpdateFailed, params: [
                AnalyticsParam.accountId: accountId,
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Create Account

    func createAccount(name: String, primaryAccountId: Int) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            ToastManager.shared.show("Account name cannot be empty.", style: .error, position: .bottom)
            return
        }
        do {
            let _: SavingsAccountDetailResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(
                    SavingsAccountAPI.create(SavingsAccountRequest.CreateAccount(nickname: trimmed, primaryAccountId: primaryAccountId, userAction: ""))
                )
            }
            analytics.log(AnalyticsEvent.savingsAccountCreated)
            await loadAccounts()
            ToastManager.shared.show("\"\(trimmed)\" account created!", style: .success, position: .bottom)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            analytics.log(AnalyticsEvent.savingsAccountCreateFailed, params: [
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            // error surfaced via BaseViewModel toast
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
    
    func createSavingAccount(request: SavingsAccountRequest.CreateAccount) async throws -> SavingsAccountInfo {
        let response: SavingsAccountDetailResponse = try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.create(request))
        }
        return response.data
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
        do {
            let result: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(SavingsAccountAPI.delete(request))
            }
            analytics.log(AnalyticsEvent.savingsAccountDeleted, params: [
                AnalyticsParam.accountId: request.accountId
            ])
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            analytics.log(AnalyticsEvent.savingsAccountDeleteFailed, params: [
                AnalyticsParam.accountId: request.accountId,
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            throw error
        }
    }
        
    // MARK: - Account Details

    func getSavingAccountDetails(accountID: Int) async throws -> SavingsAccountInfo {
        let response: SavingsAccountDetailResponse = try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(SavingsAccountAPI.details(accountId: accountID))
        }
        return response.data
    }

    func loadAccountDetail(accountID: Int) async {
        do {
            let response: SavingsAccountDetailResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(SavingsAccountAPI.details(accountId: accountID))
            }
            accountDetail = response.data
            analytics.log(AnalyticsEvent.savingsAccountDetailViewed, params: [
                AnalyticsParam.accountId: accountID
            ])
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            analytics.log(AnalyticsEvent.savingsAccountDetailFailed, params: [
                AnalyticsParam.accountId: accountID,
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            // error surfaced via BaseViewModel toast
        }
    }
}
