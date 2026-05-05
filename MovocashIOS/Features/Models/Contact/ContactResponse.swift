//
//  ContactResponse.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//
//  NOTE: These are placeholder models. Replace field names and types
//  with the actual Skinny Processor API response schema once available.

import Foundation

// MARK: - Contact List Response

nonisolated struct ContactListResponse: Decodable, Sendable {
    let contacts: [ContactRecord]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contacts = try container.decodeIfPresent([ContactRecord].self, forKey: .contacts) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case contacts
    }
}

// MARK: - Contact Record

struct ContactRecord: Decodable, Identifiable, Sendable {
    let id: String
    let nickname: String
    let phoneNumber: String
    let isFav: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id          = try container.decodeIfPresent(String.self, forKey: .id)          ?? ""
        nickname    = try container.decodeIfPresent(String.self, forKey: .nickname)    ?? ""
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        isFav       = try container.decodeIfPresent(Bool.self,   forKey: .isFav)       ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, nickname, phoneNumber
        case isFav = "is_fav"
    }
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
