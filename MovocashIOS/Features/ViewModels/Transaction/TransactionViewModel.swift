//
//  TransactionViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

@MainActor
final class TransactionViewModel: BaseViewModel {
    
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
}
