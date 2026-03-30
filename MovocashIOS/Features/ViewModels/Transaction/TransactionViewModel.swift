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

    // MARK: - Init

    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }

    // MARK: - Post Withdrawal

    func postWithdrawal(request: TransactionRequest.Withdrawal) async throws -> TransactionWithdrawalResponse {
        try await perform {
            try await self.network.request(TransactionAPI.withdrawals(request))
        }
    }

    // MARK: - Load Transactions

    func loadTransactions(max: Int, accountId: Int) async {
        do {
            let response: TransactionResponse = try await perform {
                try await self.network.request(TransactionAPI.lists(max: max, accountId: accountId))
            }
            transactions = response.transactions.map { $0.toItem() }
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Submit Internal Transfer

    /// Returns `true` on success. Errors are surfaced via BaseViewModel toast.
    @discardableResult
    func submitInternalTransfer(request: TransactionRequest.Internal) async -> Bool {
        do {
            let _: TransferInternalResponse = try await perform {
                try await self.network.request(TransactionAPI.internals(request))
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            // error surfaced via BaseViewModel toast
            return false
        }
    }
}
