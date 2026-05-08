//
//  TransactionRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

// MARK: - Transaction Filter

struct TransactionFilter {
    var max: Int = 100
    var accountId: Int
    var merchantName: String = ""
    var transactionStatus: String = ""
    var last4: String = ""
    var amount: Double? = nil
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var onDate: String = ""
    var fromDate: String = ""
    var toDate: String = ""

    var hasActiveFilters: Bool {
        !merchantName.isEmpty || !transactionStatus.isEmpty || !last4.isEmpty ||
        amount != nil || minAmount != nil || maxAmount != nil ||
        !onDate.isEmpty || !fromDate.isEmpty || !toDate.isEmpty
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "max",       value: "\(max)"),
            URLQueryItem(name: "accountId", value: "\(accountId)")
        ]
        if !merchantName.isEmpty        { items.append(.init(name: "merchantName",       value: merchantName)) }
        if !transactionStatus.isEmpty   { items.append(.init(name: "transactionStatus",  value: transactionStatus)) }
        if !last4.isEmpty               { items.append(.init(name: "last4",              value: last4)) }
        if let v = amount               { items.append(.init(name: "amount",             value: "\(v)")) }
        if let v = minAmount            { items.append(.init(name: "minAmount",          value: "\(v)")) }
        if let v = maxAmount            { items.append(.init(name: "maxAmount",          value: "\(v)")) }
        if !onDate.isEmpty              { items.append(.init(name: "onDate",             value: onDate)) }
        if !fromDate.isEmpty            { items.append(.init(name: "fromDate",           value: fromDate)) }
        if !toDate.isEmpty              { items.append(.init(name: "toDate",             value: toDate)) }
        return items
    }
}

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
        let phoneNumber: String?
        let userAction: String
        let nickname: String?
    }
}
