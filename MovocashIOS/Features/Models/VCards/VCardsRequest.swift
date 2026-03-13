//
//  VCardsRequest.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation

// MARK: - VCards

struct VCardsRequest: Codable, Equatable, Sendable {
    let pin: String
    enum CodingKeys: String, CodingKey {
        case pin = "pin"
    }
}

// MARK: - VCards Provision

struct VCardsProvisionRequest: Codable, Equatable, Sendable {
    let provider: String
    let nonce: String
    let nonceSignature: String
    let certificateChain: [String]
    enum CodingKeys: String, CodingKey {
        case provider = "provider"
        case nonce = "nonce"
        case nonceSignature = "nonceSignature"
        case certificateChain = "certificateChain"
    }
}
