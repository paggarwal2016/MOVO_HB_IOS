//
//  ContactResponse.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//

import Foundation

// MARK: - Contact List Response
// MARK: - Response

nonisolated struct ContactListResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let data: ContactsData
}

// MARK: - Data Wrapper

nonisolated struct ContactsData: Decodable, Sendable {
    let contacts: [ContactRecord]
}

// MARK: - Contact

nonisolated struct ContactRecord: Decodable, Identifiable, Sendable, Hashable {
    
    let id: String
    let isFav: Bool
    var nickname: String?
    let createdAt: Date
    var phoneNumber: String?
    let isAdded: Bool
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "contact_id"
        case isFav = "is_fav"
        case nickname
        case createdAt = "created_at"
        case phoneNumber = "phone_number"
        case isAdded = "is_added"
        case updatedAt = "updated_at"
    }
}

extension ContactRecord {
    public var isOnMovo: Bool {
        false
    }
    
    public var initials: String {
        let parts = nickname?.split(separator: " ")
        guard let first = parts?.first?.first else { return "?" }
        return String(first).uppercased()
    }
    
}







// MARK: - Recent Transfer Response (flat shape: { "contacts": [...] })

nonisolated struct RecentTransferResponse: Decodable, Sendable {
    let contacts: [ContactRecord]
}

// MARK: - Contact Action Response

nonisolated struct ContactActionResponse: Decodable, Sendable {
    let message: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case message
    }
}
