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

    // MARK: - Update ACH Account

    @discardableResult
    func updateAccount(id: Int) async -> Bool {
        do {
            let _: SuccessResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(AchAPI.updateAccount(id: id))
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.appError, params: [AnalyticsParam.errorCode: error.localizedDescription])
            return false
        }
    }
}
