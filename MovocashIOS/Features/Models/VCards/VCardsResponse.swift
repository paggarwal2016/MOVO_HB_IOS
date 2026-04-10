//
//  VCardsResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

// MARK: - VCards

nonisolated struct VCardsResponse: Decodable {
    let cardNumber: String
    let expiration: String
    let lastFour: String
    let name: String
    let cvc2: String
    let firstName: String
    let lastName: String
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
