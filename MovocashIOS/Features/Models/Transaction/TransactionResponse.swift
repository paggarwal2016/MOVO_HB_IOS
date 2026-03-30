//
//  TransactionResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation

// MARK: - Transaction Models

nonisolated struct TransactionResponse: Decodable {
    let transactions: [Transaction]
    let settledBalance: Decimal
    let balance: Decimal

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactions    = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        settledBalance  = try container.decodeIfPresent(Decimal.self, forKey: .settledBalance) ?? 0
        balance         = try container.decodeIfPresent(Decimal.self, forKey: .balance) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case transactions, settledBalance, balance
    }
}

struct Transaction: Decodable, Identifiable, Sendable {
    let id: Int
    let status: String
    let location: String?
    let description: String?
    let amount: Decimal
    let to: String?
    let from: String?
    let type: TransactionType
    let date: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id          = try container.decode(Int.self, forKey: .id)
        status      = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        location    = try container.decodeIfPresent(String.self, forKey: .location)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        amount      = try container.decodeIfPresent(Decimal.self, forKey: .amount) ?? 0
        to          = try container.decodeIfPresent(String.self, forKey: .to)
        from        = try container.decodeIfPresent(String.self, forKey: .from)
        type        = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .unknown
        date        = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, location, description, amount, to, from, type, date
    }

    func toItem() -> TransactionItem {
        let isCredit = type == .deposit
        let title    = isCredit
            ? (from ?? description ?? "Unknown")
            : (to   ?? description ?? "Unknown")
        let formatter = ISO8601DateFormatter()
        return TransactionItem(
            id:       id,
            title:    title,
            subtitle: type.displayTitle,
            amount:   amount,
            isCredit: isCredit,
            date:     formatter.date(from: date) ?? Date(),
            rawDate:  date
        )
    }
}

enum TransactionType: String, Decodable, Sendable {
    case deposit  = "Deposit"
    case withdraw = "Withdraw"
    case payment  = "Payment"
    case transfer = "Transfer"
    case unknown  = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = TransactionType(rawValue: raw) ?? .unknown
    }

    var displayTitle: String { rawValue }
}

// MARK: - TransactionItem

struct TransactionItem: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let amount: Decimal
    let isCredit: Bool
    let date: Date
    let rawDate: String

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var amountFormatted: String {
        let prefix = isCredit ? "+" : "-"
        let abs    = NSDecimalNumber(decimal: Swift.abs(amount)).doubleValue
        let str    = Self.amountFormatter.string(from: NSNumber(value: abs)) ?? String(format: "%.2f", abs)
        return "\(prefix)$\(str)"
    }
}



// MARK: - Transaction Withdrawal Response

nonisolated struct TransactionWithdrawalResponse: Codable {
    let transactionId: Int
}

// MARK: - Transfer Internal Response

nonisolated struct TransferInternalResponse: Codable {
    let transferId: Int
}
