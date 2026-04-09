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
    let plaidAccountBalance: Double
    let isPlaidLoginRequired: Bool
    let isDefault: Bool
    let institutionLogo: String
    let accountNumber: String
    let accountName: String
    let institutionName: String
    let achAccountId: Int

    // MARK: - Display Helpers

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: plaidAccountBalance)) ?? "$0.00"
    }

    var logoImage: UIImage? {
        guard !institutionLogo.isEmpty,
              let data = Data(base64Encoded: institutionLogo, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }
}
