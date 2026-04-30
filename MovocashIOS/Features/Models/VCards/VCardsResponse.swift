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

extension VCardListResponse {

    var fullName: String {
        [firstName, middleName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var maskedNumber: String {
        guard let lastFour else { return "•••• •••• •••• ••••" }
        return "••••   ••••   ••••   \(lastFour)"
    }

    var formattedExpiry: String {
        expiration ?? "--/--"
    }

    var displayBalance: String {
        "$ 0.00" // 👉 replace with real API field later
    }
}

nonisolated struct VCardListAllResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: [VCardListResponse]?
}


struct CardUIModel: Identifiable {
    let id = UUID()
    let balanceText: String
    let cardNumber: String
    let expiry: String
    let holderName: String
    let brand: String
}

extension VCardListResponse {
    func toUIModel() -> CardUIModel {
        CardUIModel(
            balanceText: displayBalance,
            cardNumber: maskedNumber,
            expiry: formattedExpiry,
            holderName: fullName.isEmpty ? (name ?? "N/A") : fullName,
            brand: "VISA" // or from API later
        )
    }
}
