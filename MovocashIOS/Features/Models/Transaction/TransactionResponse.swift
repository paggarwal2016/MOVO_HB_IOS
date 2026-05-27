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
        let container       = try decoder.container(keyedBy: CodingKeys.self)
        transactions        = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        let settledBalStr   = try container.decodeIfPresent(String.self, forKey: .settledBalance) ?? "0"
        let balanceStr      = try container.decodeIfPresent(String.self, forKey: .balance) ?? "0"
        settledBalance      = Decimal(string: settledBalStr) ?? 0
        balance             = Decimal(string: balanceStr) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case transactions, settledBalance, balance
    }
}

struct Transaction: Decodable, Identifiable, Sendable {
    let id: Int
    let status: String?
    let location: String?
    let description: String?
    let amount: Decimal
    let to: String?
    let from: String?
    let type: TransactionType
    let date: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id              = try container.decode(Int.self, forKey: .id)
        status          = try container.decodeIfPresent(String.self, forKey: .status)
        location        = try container.decodeIfPresent(String.self, forKey: .location)
        description     = try container.decodeIfPresent(String.self, forKey: .description)
        let amountStr   = try container.decodeIfPresent(String.self, forKey: .amount) ?? "0"
        amount          = Decimal(string: amountStr) ?? 0
        to              = try container.decodeIfPresent(String.self, forKey: .to)
        from            = try container.decodeIfPresent(String.self, forKey: .from)
        type            = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .unknown
        date            = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, location, description, amount, to, from, type, date
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yyyy HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func toItem() -> TransactionItem {
        let isCredit   = type == .deposit
        let locNil     = location.flatMap  { $0.isEmpty ? nil : $0 }
        let fromNil    = from?.isEmpty == false ? from : nil
        let toNil      = to?.isEmpty   == false ? to   : nil
        let descNil    = description?.isEmpty == false ? description : nil
        let title: String
        if isCredit {
            // Deposit: prefer source name (from), then location label, then description
            title = fromNil ?? locNil ?? descNil ?? "Unknown"
        } else {
            // Payment / Transfer: prefer recipient (to), then description
            title = toNil ?? descNil ?? "Unknown"
        }
        let parsedDate = Self.dateFormatter.date(from: date) ?? Date()
        return TransactionItem(
            id:       id,
            title:    title,
            subtitle: type.displayTitle,
            amount:   amount,
            isCredit: isCredit,
            date:     parsedDate,
            rawDate:  date,
            status:   status ?? "",
            type:     type
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
    let status: String
    let type: TransactionType

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

// MARK: - Check Intent Response
// Matches POST /transactions/check-intent:
//   { "success": true, "message": "...", "exists": true|false }

nonisolated struct CheckIntentResponse: Decodable {
    /// Whether the API call itself succeeded.
    let success: Bool
    /// Optional human-readable reason from the server.
    let message: String?
    /// `true` → recipient exists and transfer is permitted.
    /// `false` → recipient not found; Pay button should be blocked.
    let exists: Bool
}
