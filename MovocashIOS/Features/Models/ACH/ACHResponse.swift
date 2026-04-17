//
//  ACHResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import Foundation
import UIKit

nonisolated struct ACHResponse: Codable, Sendable {
    let achAccounts: [ACHAccount]
}

nonisolated struct ACHAccount: Codable, Sendable, Equatable {
    let plaidAccountId: String
    let plaidAccountBalance: Decimal
    let isPlaidLoginRequired: Bool
    let isDefault: Bool
    let institutionLogo: String
    let accountNumber: String
    let accountName: String
    let institutionName: String
    let achAccountId: Int

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plaidAccountId       = try c.decodeIfPresent(String.self, forKey: .plaidAccountId) ?? ""
        isPlaidLoginRequired = try c.decodeIfPresent(Bool.self,   forKey: .isPlaidLoginRequired) ?? false
        isDefault            = try c.decodeIfPresent(Bool.self,   forKey: .isDefault) ?? false
        institutionLogo      = try c.decodeIfPresent(String.self, forKey: .institutionLogo) ?? ""
        accountNumber        = try c.decodeIfPresent(String.self, forKey: .accountNumber) ?? ""
        accountName          = try c.decodeIfPresent(String.self, forKey: .accountName) ?? ""
        institutionName      = try c.decodeIfPresent(String.self, forKey: .institutionName) ?? ""
        achAccountId         = try c.decodeIfPresent(Int.self,    forKey: .achAccountId) ?? 0
        let balStr           = try c.decodeIfPresent(String.self, forKey: .plaidAccountBalance) ?? "0"
        plaidAccountBalance  = Decimal(string: balStr) ?? 0
    }

    // MARK: - Memberwise Init (used in ACHViewModel.updateAccount)

    init(
        plaidAccountId: String,
        plaidAccountBalance: Decimal,
        isPlaidLoginRequired: Bool,
        isDefault: Bool,
        institutionLogo: String,
        accountNumber: String,
        accountName: String,
        institutionName: String,
        achAccountId: Int
    ) {
        self.plaidAccountId       = plaidAccountId
        self.plaidAccountBalance  = plaidAccountBalance
        self.isPlaidLoginRequired = isPlaidLoginRequired
        self.isDefault            = isDefault
        self.institutionLogo      = institutionLogo
        self.accountNumber        = accountNumber
        self.accountName          = accountName
        self.institutionName      = institutionName
        self.achAccountId         = achAccountId
    }

    // MARK: - Display Helpers

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    var formattedBalance: String {
        Self.currencyFormatter.string(from: NSDecimalNumber(decimal: plaidAccountBalance)) ?? "$0.00"
    }

    var logoImage: UIImage? {
        guard !institutionLogo.isEmpty,
              let data = Data(base64Encoded: institutionLogo, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }
}
