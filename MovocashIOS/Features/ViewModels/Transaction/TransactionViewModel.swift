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
    
    // MARK: - Get
    
    func getTransactionList(max: Int, accountId: Int) async throws -> TransactionResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(TransactionAPI.lists(max: max, accountId: accountId))
        }
    }
        
    // MARK: - Post
    
    func postWithdrawal(request: TransactionRequest.Withdrawal) async throws -> TransactionWithdrawalResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(TransactionAPI.withdrawals(request))
        }
    }
        
    // MARK: - Post Internal

    func postInternal(request: TransactionRequest.Internal) async throws -> TransferInternalResponse {
        try await perform { [weak self] in
            guard let self else { throw ModelError.deallocated }
            return try await network.request(TransactionAPI.internals(request))
        }
    }

    // MARK: - Load Transactions

    func loadTransactions(max: Int, accountId: Int) async {
        do {
            let response: TransactionResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(TransactionAPI.lists(max: max, accountId: accountId))
            }
            transactions = response.transactions.isEmpty
                ? TransactionItem.dummy
                : response.transactions.map { $0.toItem() }
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            transactions = TransactionItem.dummy
        }
    }

    // MARK: - Submit Internal Transfer

    func submitInternalTransfer(request: TransactionRequest.Internal, onSuccess: @escaping () -> Void) async {
        do {
            let _: TransferInternalResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(TransactionAPI.internals(request))
            }
            onSuccess()
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }
}
