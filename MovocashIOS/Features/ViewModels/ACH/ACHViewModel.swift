//
//  ACHViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation
import Combine

final class ACHViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var accounts: [ACHAccount] = []
    @Published var hasFetched: Bool = false

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics:  AnalyticsTracking? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }

    // MARK: - Seed from Dashboard (avoids empty-state flash on first open)

    func seed(accounts initialAccounts: [ACHAccount]) {
        guard accounts.isEmpty else { return }
        accounts = initialAccounts
    }

    // MARK: - Bind Linked Account (local — no network)

    /// Inserts a newly linked account into the in-memory store without a fetch.
    /// Deduplicates by `plaidAccountId` so re-linking the same account is a no-op.
    /// The full account record (real balance / achAccountId) is filled in by a
    /// later explicit `fetchAccounts()` / `refresh()`.
    func addLinkedAccount(_ account: ACHAccount) {
        guard !accounts.contains(where: { $0.plaidAccountId == account.plaidAccountId }) else { return }
        accounts.insert(account, at: 0)
    }

    // MARK: - Fetch ACH Accounts

    func fetchAccounts() async {
        do {
            let response: ACHResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.getAccounts)
            }
            accounts = response.achAccounts
            hasFetched = true
            analytics.log(AnalyticsEvent.achAccountsViewed, params: [
                AnalyticsParam.count: accounts.count
            ])
        } catch is CancellationError {
            // Task cancelled — no action needed
        } catch {
            analytics.log(AnalyticsEvent.achAccountsFetchFailed, params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription])
        }
    }

    // Pull-to-refresh — bypasses perform() so state stays idle,
    // preventing ProfileScreen from re-rendering and cancelling the refreshable task.
    func refresh() async {
        do {
            let response: ACHResponse = try await network.request(AchAPI.getAccounts)
            accounts = response.achAccounts
            hasFetched = true
            analytics.log(AnalyticsEvent.achAccountsViewed, params: [
                AnalyticsParam.count: accounts.count
            ])
        } catch is CancellationError {
            SecureLogger.warning("ACH refresh cancelled — task cancelled before response", category: .network)
        } catch {
            analytics.log(AnalyticsEvent.achAccountsFetchFailed, params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription])
            if error.shouldShowUserFacingToast {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
        }
    }

    // MARK: - Initiate ACH Transfer

    @discardableResult
    func initiateTransfer(request: ACHRequest) async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.initiateTransfer(request))
            }
            analytics.log(AnalyticsEvent.achTransferInitiated, params: [
                AnalyticsParam.amountRange: AnalyticsBucket.amount(Double(request.amount))
            ])
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.achTransferFailed, params: [
                AnalyticsParam.amountRange: AnalyticsBucket.amount(Double(request.amount)),
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            return false
        }
    }

    // MARK: - Delete ACH Account

    @discardableResult
    func deleteAccount(id: Int) async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.deleteAccount(id: id))
            }
            accounts.removeAll { $0.achAccountId == id }
            analytics.log(AnalyticsEvent.achAccountDeleted)
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.achAccountDeleteFailed, params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription])
            return false
        }
    }

    // MARK: - Update ACH Account (set as default)

    @discardableResult
    func updateAccount(id: Int) async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.updateAccount(id: id))
            }
            accounts = accounts.map {
                ACHAccount(
                    plaidAccountId: $0.plaidAccountId,
                    plaidAccountBalance: $0.plaidAccountBalance,
                    isPlaidLoginRequired: $0.isPlaidLoginRequired,
                    isDefault: $0.achAccountId == id,
                    institutionLogo: $0.institutionLogo,
                    accountNumber: $0.accountNumber,
                    accountName: $0.accountName,
                    institutionName: $0.institutionName,
                    achAccountId: $0.achAccountId
                )
            }
            //await fetchAccounts() // TODO:- future option
            analytics.log(AnalyticsEvent.achAccountSetDefault)
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.achAccountSetDefaultFailed, params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription])
            return false
        }
    }
}
