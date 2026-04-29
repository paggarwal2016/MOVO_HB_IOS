//
//  TransactionViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation
import Combine

@MainActor
final class TransactionViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var transactions: [TransactionItem] = []

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

    // MARK: - Post Withdrawal

    func postWithdrawal(request: TransactionRequest.Withdrawal) async throws -> TransactionWithdrawalResponse {
        do {
            let response: TransactionWithdrawalResponse = try await perform {
                try await self.network.request(TransactionAPI.withdrawals(request))
            }
            analytics.log(AnalyticsEvent.withdrawalInitiated, params: [
                AnalyticsParam.accountId: request.accountId,
                AnalyticsParam.amount: request.transactionAmount,
                AnalyticsParam.savingsAccountId: request.savingsAccountId
            ])
            return response
        } catch {
            analytics.log(AnalyticsEvent.withdrawalFailed, params: [
                AnalyticsParam.accountId: request.accountId,
                AnalyticsParam.amount: request.transactionAmount
            ])
            throw error
        }
    }

    // MARK: - Load Transactions

    func loadTransactions(max: Int, accountId: Int) async {
        do {
            let response: TransactionResponse = try await perform {
                try await self.network.request(TransactionAPI.lists(max: max, accountId: accountId))
            }
            transactions = response.transactions.map { $0.toItem() }
            analytics.log(AnalyticsEvent.transactionListViewed, params: [
                AnalyticsParam.accountId: accountId,
                AnalyticsParam.count: response.transactions.count
            ])
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Submit Internal Transfer

    /// Returns `true` on success. Falls back to external transfer if recipient has no Movo account.
    @discardableResult
    func submitInternalTransfer(request: TransactionRequest.Internal) async -> Bool {
        do {
            let _: TransferInternalResponse = try await performSilent {
                try await self.network.request(TransactionAPI.internals(request))
            }
            analytics.log(AnalyticsEvent.internalTransferInitiated, params: [
                AnalyticsParam.amount: request.amount,
                AnalyticsParam.fromAccountId: request.fromAccountId,
                AnalyticsParam.toAccountId: request.toAccountId
            ])
            return true
        } catch NetworkError.serverMessage(let message) where message == "A customer with this phone number does not exist" {
            return await submitExternalTransfer(from: request)
        } catch is CancellationError {
            return false
        } catch {
            ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            analytics.log(AnalyticsEvent.internalTransferFailed, params: [
                AnalyticsParam.amount: request.amount,
                AnalyticsParam.fromAccountId: request.fromAccountId,
                AnalyticsParam.toAccountId: request.toAccountId
            ])
            return false
        }
    }

    // MARK: - Submit External Transfer

    @discardableResult
    private func submitExternalTransfer(from internalRequest: TransactionRequest.Internal) async -> Bool {
        let externalRequest = TransactionRequest.External(
            description: internalRequest.description,
            amount: internalRequest.amount,
            recipientPhoneNumber: internalRequest.phoneNumber ?? "",
            fromAccountId: internalRequest.fromAccountId,
            smsMessage: "External Transfer"
        )
        do {
            let _: TransferExternalResponse = try await perform {
                try await self.network.request(TransactionAPI.external(externalRequest))
            }
            analytics.log(AnalyticsEvent.internalTransferInitiated, params: [
                AnalyticsParam.amount: externalRequest.amount,
                AnalyticsParam.fromAccountId: externalRequest.fromAccountId
            ])
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.internalTransferFailed, params: [
                AnalyticsParam.amount: externalRequest.amount,
                AnalyticsParam.fromAccountId: externalRequest.fromAccountId
            ])
            return false
        }
    }
}
