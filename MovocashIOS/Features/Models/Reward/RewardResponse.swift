//
//  RewardResponse.swift
//  MovocashIOS
//
//  Created by Vinu on 24/03/26.
//

import Foundation

nonisolated struct RewardResponse: Decodable, Sendable {
    let email: String
    let points:Int
}

nonisolated struct RewardEnrollResponse: Decodable, Sendable {
    let merryJaneEnrolledAt: String
    let merryJaneEmail: String
    let merryJaneActive: Bool
}
