//
//  SavingsAccountRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation

enum SavingsAccountRequest {

    // POST /savings/account
    struct CreateAccount: Codable, Equatable, Sendable {
        let nickname: String
    }

    // PATCH /savings/account
    struct UpdateAccount: Codable, Equatable, Sendable {
        let nickname: String
        let accountId: Int
    }

    // DELETE /savings/account
    struct DeleteAccount: Codable, Equatable, Sendable {
        let targetAccountId: Int
        let accountId: Int
    }
}


// MARK: - Sort Options

enum SavingsSortBy: String, Equatable {
    case id
    case clientId
    case accountNumber
    case clientName
    case status
    case accountBalance
    case availableBalance
    case nickname
    case isPrimary
}

enum SavingsSortDirection: String, Equatable {
    case asc
    case desc
}
