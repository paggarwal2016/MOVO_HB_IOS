//
//  TransactionRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

enum TransactionRequest {
    
    // MARK: - Withdrawal Request
    struct Withdrawal: Encodable {
        let accountId: Int
        let transactionAmount: Double
        let savingsAccountId: Int
    }
    
    // MARK: - Internal Request
    
    struct Internal: Encodable {
        let description: String
        let amount: Double
        let toAccountId: Int
        let toClientId: Int
        let fromAccountId: Int
    }
}
