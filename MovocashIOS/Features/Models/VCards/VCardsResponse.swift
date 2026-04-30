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
    let cvc2: String?
    let lastName: String?
    let middleName: String?
    let firstName: String?
    let name: String?
    let lastFour: String?
    let expiration: String?
    let cardNumber: String?
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
        guard let lastFour else { return "•••• •••• •••• ••••" }
        return "•••• •••• •••• \(lastFour)"
    }

    var formattedExpiry: String {
        expiration ?? "--/--"
    }

    var displayBalance: String {
        "$ 0.00"
    }
}

nonisolated struct VCardListAllResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: [VCardListResponse]?
}


