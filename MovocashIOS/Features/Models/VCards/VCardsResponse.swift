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
    
    enum CodingKeys: String, CodingKey {
        case cardNumber = "cardNumber"
        case expiration = "expiration"
        case lastFour = "lastFour"
        case name = "name"
        case cvc2 = "cvc2"
        case firstName = "firstName"
        case lastName = "lastName"
    }
}

// MARK: - VCards Provision

nonisolated struct VCardsProvisionResponse: Decodable {
    let encryptedData: String
    let ephemeralPublicKey: String
    let activationData: String
    
    enum CodingKeys: String, CodingKey {
        case encryptedData = "encryptedData"
        case ephemeralPublicKey = "ephemeralPublicKey"
        case activationData = "activationData"
    }
}
