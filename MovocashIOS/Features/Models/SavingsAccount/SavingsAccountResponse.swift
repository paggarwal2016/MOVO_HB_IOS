//
//  SavingsAccountResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation

// MARK: - Savings List

nonisolated struct SavingsAccountListResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: SavingsAccountData
}

nonisolated struct SavingsAccountData: Decodable, Sendable {
    let accounts: [SavingsAccountDetailsResponse]
    let totalAccountBalance: Decimal
    let totalAvailableBalance: Decimal

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts              = try container.decodeIfPresent([SavingsAccountDetailsResponse].self, forKey: .accounts) ?? []
        let totalAccStr       = try container.decodeIfPresent(String.self, forKey: .totalAccountBalance) ?? "0"
        let totalAvailStr     = try container.decodeIfPresent(String.self, forKey: .totalAvailableBalance) ?? "0"
        totalAccountBalance   = Decimal(string: totalAccStr) ?? 0
        totalAvailableBalance = Decimal(string: totalAvailStr) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, totalAccountBalance, totalAvailableBalance
    }
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
    
    // MARK: - Coding Keys
    
    enum CodingKeys: CodingKey {
        case id
        case accountNumber
        case clientName
        case status
        case accountBalance
        case availableBalance
        case clientId
        case nickname
        case isPrimary
    }
    
    // MARK: - Custom Decoder
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        accountNumber = try container.decode(String.self, forKey: .accountNumber)
        clientName = try container.decode(String.self, forKey: .clientName)
        status = try container.decode(AccountStatus.self, forKey: .status)
        let accBalStr    = try container.decodeIfPresent(String.self, forKey: .accountBalance) ?? "0"
        let availBalStr  = try container.decodeIfPresent(String.self, forKey: .availableBalance) ?? "0"
        accountBalance   = Decimal(string: accBalStr) ?? 0
        availableBalance = Decimal(string: availBalStr) ?? 0
        clientId = try container.decode(Int.self, forKey: .clientId)
        
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        isPrimary = try container.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    }
    
    // MARK: - Display Helpers
    
    var displayName: String {
        nickname ?? maskedAccountNumber
    }
    
    var maskedAccountNumber: String {
        "•••• \(accountNumber.suffix(4))"
    }
    
    // MARK: - Balance Formatting
    
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
    
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var formattedBalance: String {
        Self.currencyFormatter.string(
            from: NSDecimalNumber(decimal: availableBalance)
        ) ?? "$0.00"
    }
    
    var balanceParts: (whole: String, cents: String) {
        let formatted = Self.decimalFormatter.string(
            from: NSDecimalNumber(decimal: availableBalance)
        ) ?? "0.00"
        
        let parts = formatted.split(separator: ".")
        
        return (
            whole: String(parts.first ?? "0"),
            cents: String(parts.last ?? "00")
        )
    }
    
    // MARK: - Status Helpers

    var isActive: Bool {
        status == .active
    }

    var formattedAccountBalance: String {
        Self.currencyFormatter.string(from: NSDecimalNumber(decimal: accountBalance)) ?? "$0.00"
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
    
}
