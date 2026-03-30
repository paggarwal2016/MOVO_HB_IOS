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
