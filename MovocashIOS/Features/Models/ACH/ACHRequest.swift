//
//  ACHRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation

struct ACHRequest: Encodable, Sendable {
    let source: String
    let amount: Int
    let achAccountId: Int
    let userAction: String
}

struct PlaidAccountRequest: Encodable, Sendable {
    let status: String
    let accountsAdded: [PlaidAccount]
    let userAction: String
}

struct PlaidAccount: Encodable, Sendable {
    let plaidAccountId: String
    let resourceId: Int
    let savingsId: Int
    let customerId: Int
    let officeId: Int
}
