//
//  VCardsResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

// MARK: - VCards

nonisolated struct VCardsResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: [VCardsList]?
}

nonisolated struct VCardsList: Decodable, Sendable {
    let cardNumber: String?
    let expiration: String?
    let lastFour: String?
    let name: String?
    let cvc2: String?
    let firstName: String?
    let lastName: String?
    let middleName: String?
}

// MARK: - VCards Primary (single object response)

nonisolated struct VCardPrimaryResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: VCardsList?
}

// MARK: - Create VCard (encrypted response)

nonisolated struct CreateVCardEncryptedData: Decodable, Sendable {
    let encryptedData: String
}

nonisolated struct CreateVCardEncryptedResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: CreateVCardEncryptedData?
}

// MARK: - VCards Provision

nonisolated struct VCardsProvisionResponse: Decodable {
    let encryptedData: String
    let ephemeralPublicKey: String
    let activationData: String
}

nonisolated struct VCardListResponse: Codable, Sendable {
    let savingsAccountId: Int?
    let savingsAccountNickname: String?
    let savingsAccountBalance: Double?
    let savingsAccountAvailableBalance: Double?
    let cvc2: String?
    let lastName: String?
    let middleName: String?
    let firstName: String?
    let name: String?
    let lastFour: String?
    let expiration: String?
    let cardNumber: String?
    /// Whether the card is active. Disabled cards are filtered out of the dashboard list.
    let enabled: Bool?
}

extension VCardListResponse: Identifiable {
    public var id: String { "\(savingsAccountId ?? 0)-\(lastFour ?? "")" }
}

extension VCardListResponse {

    var fullName: String {
        [firstName, middleName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var displayName: String {
        fullName.isEmpty ? (name ?? "N/A") : fullName
    }

    var maskedNumber: String {
        if let number = cardNumber, number.count == 16 {
            let last = String(number.suffix(4))
            return "•••• •••• •••• \(last)"
        }
        guard let lastFour else { return "•••• •••• •••• ••••" }
        return "•••• •••• •••• \(lastFour)"
    }

    var formattedExpiry: String {
        expiration ?? "--/--"
    }

    /// Expiry as `MM/YY` from the API's `YYYY-MM` value, e.g. "2028-05" → "05/28".
    var expiryMMYY: String {
        let parts = (expiration ?? "").split(separator: "-")
        if parts.count == 2, parts[0].count == 4 {
            return "\(parts[1])/\(parts[0].suffix(2))"
        }
        return expiration ?? "--/--"
    }

    /// Cardholder in "FIRST L." form, e.g. "LAYTON C.".
    var cardHolderShort: String {
        let first = firstName ?? name?.split(separator: " ").first.map(String.init) ?? ""
        let lastInitial = (lastName ?? "").first.map { "\($0)." } ?? ""
        let combined = [first, lastInitial].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? displayName : combined
    }

    var displayBalance: String {
        let amount = savingsAccountAvailableBalance ?? savingsAccountBalance ?? 0
        return String(format: "$ %.2f", amount)
    }

    var currencyCode: String {
        "USD"
    }

    var balance: Decimal {
        Decimal(savingsAccountBalance ?? 0)
    }
    
    var isActive: Bool {
        true
    }
    var tier: String {
        "debit"
    }
    
    var fullNumberPasteboard: String {
        cardNumber ?? ""
    }
}

nonisolated struct VCardListAllResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: [VCardListResponse]?
}


