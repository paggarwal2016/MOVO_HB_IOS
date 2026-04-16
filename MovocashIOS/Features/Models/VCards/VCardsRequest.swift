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
    let accountId: Int
    let userAction: String
}

// MARK: - VCards Provision

struct VCardsProvisionRequest: Codable, Equatable, Sendable {
    let provider: String
    let nonce: String
    let nonceSignature: String
    let certificateChain: [String]
}
