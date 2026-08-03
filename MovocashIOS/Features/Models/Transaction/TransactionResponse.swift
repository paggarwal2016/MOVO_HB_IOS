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
    let metadata: Metadata?

    /// Server pagination metadata. `totalRecords` is the authoritative way to know
    /// whether more pages remain.
    nonisolated struct Metadata: Decodable {
        let offset: Int?
        let limit: Int?
        let totalRecords: Int?
    }

    init(from decoder: Decoder) throws {
        let container  = try decoder.container(keyedBy: CodingKeys.self)
        transactions   = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        settledBalance = Self.decodeDecimal(from: container, key: .settledBalance)
        balance        = Self.decodeDecimal(from: container, key: .balance)
        metadata       = try container.decodeIfPresent(Metadata.self, forKey: .metadata)
    }

    private static func decodeDecimal(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Decimal {
        if let d = try? container.decodeIfPresent(Double.self, forKey: key) { return Decimal(d) }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Decimal(string: s) ?? 0 }
        return 0
    }

    private enum CodingKeys: String, CodingKey {
        case transactions, settledBalance, balance, metadata
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
        if let d = try? container.decodeIfPresent(Double.self, forKey: .amount) {
            amount = Decimal(string: String(d)) ?? Decimal(d)
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .amount) {
            amount = Decimal(string: s) ?? 0
        } else {
            amount = 0
        }
        to              = try container.decodeIfPresent(String.self, forKey: .to)
        from            = try container.decodeIfPresent(String.self, forKey: .from)
        type            = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .unknown
        // The API field is `createdAt`; keep `date` as a fallback for older payloads.
        date            = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, location, description, amount, to, from, type, date, createdAt
    }

    // The backend sends timestamps in UTC with no offset, so the source zone
    // must be pinned explicitly — otherwise the device's local zone is used to
    // interpret it, producing a different absolute instant depending on where
    // the device's clock is set.
    private static func utcFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
       // f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    // Matches `createdAt`, e.g. "2026-07-25T00:10:19".
    private static let createdAtFormatter = utcFormatter("yyyy-MM-dd'T'HH:mm:ss")

    // Matches the legacy `date` field, e.g. "7/25/2026 00:10:19" — same UTC
    // instant as `createdAt`, just a different format.
    private static let legacyDateFormatter = utcFormatter("M/d/yyyy HH:mm:ss")

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
        let parsedDate = Self.createdAtFormatter.date(from: date)
            ?? Self.legacyDateFormatter.date(from: date)
            ?? Date()
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
    let success: Bool
    let message: String?
    let exists: Bool
    let disclaimer: String?
}
