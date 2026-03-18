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

    nonisolated(unsafe) private static let dateFormatter = ISO8601DateFormatter()

    func toItem() -> TransactionItem {
        let isCredit = type == .deposit
        let title    = isCredit
            ? (from ?? description ?? "Unknown")
            : (to   ?? description ?? "Unknown")
        return TransactionItem(
            id:       id,
            title:    title,
            subtitle: type.rawValue,
            amount:   amount,
            isCredit: isCredit,
            date:     Self.dateFormatter.date(from: date) ?? Date(),
            rawDate:  date
        )
    }
}

enum TransactionType: String, Decodable, Sendable {
    case deposit  = "Deposit"
    case withdraw = "Withdraw"
    case payment  = "Payment"
    case transfer = "Transfer"
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

    // Static dummy data — allocated once, never recreated
#if DEBUG
    static let dummy: [TransactionItem] = [
        TransactionItem(id: 1, title: "Eva Novak",     subtitle: "Deposit",  amount: 5710.20, isCredit: true,  date: Date(), rawDate: ""),
        TransactionItem(id: 2, title: "Binance",       subtitle: "Deposit",  amount: 714.00,  isCredit: true,  date: Date(), rawDate: ""),
        TransactionItem(id: 3, title: "Henrik Jansen", subtitle: "Deposit",  amount: 428.00,  isCredit: true,  date: Date(), rawDate: ""),
        TransactionItem(id: 4, title: "Multiplex",     subtitle: "Payment",  amount: 124.55,  isCredit: false, date: Date(), rawDate: ""),
        TransactionItem(id: 5, title: "Nike",          subtitle: "Payment",  amount: 328.96,  isCredit: false, date: Date(), rawDate: ""),
        TransactionItem(id: 6, title: "Matteo Ricci",  subtitle: "Deposit",  amount: 548.00,  isCredit: true,  date: Date(), rawDate: ""),
        TransactionItem(id: 7, title: "Megogo",        subtitle: "Withdraw", amount: 847.20,  isCredit: false, date: Date(), rawDate: ""),
        TransactionItem(id: 8, title: "Emilia Costa",  subtitle: "Deposit",  amount: 147.00,  isCredit: true,  date: Date(), rawDate: ""),
    ]
#endif
}



// MARK: - Transaction Withdrawal Response

nonisolated struct TransactionWithdrawalResponse: Codable {
    let transactionId: Int
}

// MARK: - Transfer Internal Response

nonisolated struct TransferInternalResponse: Codable {
    let transferId: Int
}
