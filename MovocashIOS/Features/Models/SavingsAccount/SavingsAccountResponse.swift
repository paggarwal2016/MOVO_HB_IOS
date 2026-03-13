//
//  SavingsAccountResponse.swift
//  MovocashIOS
//
//  Created by Vinu on 13/03/26.
//

import Foundation
import SwiftUI

// MARK: - Savings List

nonisolated struct SavingsAccountListResponse: Decodable {
    let accounts: [SavingsAccountDetailsResponse]
    let totalAccountBalance: Decimal
    let totalAvailableBalance: Decimal
}

// MARK: - Savings Details

nonisolated struct SavingsAccountDetailsResponse: Decodable, Sendable, Identifiable {
    let id: Int
    let accountNumber: String
    let clientName: String
    let status: AccountStatus
    let accountBalance: Decimal
    let availableBalance: Decimal
    let clientId: Int
    let nickname: String?
    let isPrimary: Bool
    
    // MARK: - Display
    
    var displayName: String {
        nickname ?? maskedAccountNumber
    }
    
    var maskedAccountNumber: String {
        "•••• \(accountNumber.suffix(4))"
    }
    
    // MARK: - Balance
    
    var formattedBalance: String {      
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: availableBalance)) ?? "$0.00"
    }
    
    var balanceParts: (whole: String, cents: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSDecimalNumber(decimal: availableBalance)) ?? "0.00"
        let parts = formatted.split(separator: ".")
        return (
            whole: String(parts.first ?? "0"),
            cents: String(parts.last ?? "00")
        )
    }
    
    var isActive: Bool {
        status == .active
    }
}

// MARK: - Account Status

enum AccountStatus: String, Decodable, Sendable {
    case active   = "Active"
    case inactive = "Inactive"
    case frozen   = "Frozen"
    case closed   = "Closed"
    case unknown  = "Unknown"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = AccountStatus(rawValue: value) ?? .unknown
    }
    
    var displayTitle: String {
        switch self {
        case .active:   return "Active"
        case .inactive: return "Inactive"
        case .frozen:   return "Frozen"
        case .closed:   return "Closed"
        case .unknown:  return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .active:   return .green
        case .inactive: return .gray
        case .frozen:   return .blue
        case .closed:   return .red
        case .unknown:  return .orange
        }
    }
}
