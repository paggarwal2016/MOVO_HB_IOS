//
//  ACHResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation

nonisolated struct ACHResponse: Decodable, Sendable {
    let achAccounts: [ACHAccount]
}

nonisolated struct ACHAccount: Decodable, Sendable {
    let plaidAccountId: String
    let plaidAccountBalance: Double
    let isPlaidLoginRequired: Bool
    let isDefault: Bool
    let institutionLogo: String
    let accountNumber: String
    let accountName: String
    let institutionName: String
    let achAccountId: Int
}
