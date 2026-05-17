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

    // MARK: - Fetch ACH Accounts

    func fetchAccounts() async {
        do {
            let response: ACHResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.getAccounts)
            }
            accounts = response.achAccounts
        } catch is CancellationError {
            // Task cancelled — no action needed
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
        }
    }

    // Pull-to-refresh — bypasses perform() so state stays idle,
    // preventing ProfileScreen from re-rendering and cancelling the refreshable task.
    func refresh() async {
        do {
            let response: ACHResponse = try await network.request(AchAPI.getAccounts)
            accounts = response.achAccounts
        } catch is CancellationError {
            SecureLogger.warning("ACH refresh cancelled — task cancelled before response", category: .network)
        } catch {
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
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
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
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
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
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
            return false
        }
    }
}
