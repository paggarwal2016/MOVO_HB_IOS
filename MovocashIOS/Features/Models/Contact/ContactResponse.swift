//
//  ContactResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/05/26.
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

    /// True when a non-empty nickname is present.
    var hasNickname: Bool {
        !(nickname?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    /// Single avatar character: nickname initial when present, otherwise the
    /// first local digit of the phone number, falling back to "?".
    var avatarInitial: String {
        if hasNickname { return initials }
        let digits = PhoneNumberValidator.sanitize(phoneNumber ?? "")
        return digits.first.map { String($0) } ?? "?"
    }

    /// Primary display label: nickname when present, otherwise the phone number.
    var displayName: String {
        hasNickname ? (nickname ?? "") : (phoneNumber ?? "")
    }

    /// Whether the phone number is a valid US (NANP) number.
    var hasValidPhone: Bool {
        PhoneNumberValidator.isValidUSNumber(PhoneNumberValidator.sanitize(phoneNumber ?? ""))
    }
}







// MARK: - Recent Transfer Response (flat shape: { "contacts": [...] })

nonisolated struct RecentTransferResponse: Decodable, Sendable {
    let contacts: [RecordContact]
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



nonisolated struct RecordContact: Decodable, Sendable, Identifiable {
    var id: String { phoneNumber ?? nickname ?? "" }
    let nickname: String?
    var lastSentAt: String?
    var phoneNumber: String?
}

extension RecordContact {
    /// True when a non-empty nickname is present.
    var hasNickname: Bool {
        !(nickname?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    /// Nickname initial, uppercased; "?" when no nickname.
    var initials: String {
        guard let first = nickname?.split(separator: " ").first?.first else { return "?" }
        return String(first).uppercased()
    }

    /// Single avatar character: nickname initial when present, otherwise the
    /// first local digit of the phone number, falling back to "?".
    var avatarInitial: String {
        if hasNickname { return initials }
        let digits = PhoneNumberValidator.sanitize(phoneNumber ?? "")
        return digits.first.map { String($0) } ?? "?"
    }

    /// Primary display label: nickname when present, otherwise the phone number.
    var displayName: String {
        hasNickname ? (nickname ?? "") : (phoneNumber ?? "")
    }

    /// First word of the nickname (for compact cells), otherwise the phone number.
    var compactLabel: String {
        hasNickname
            ? (nickname?.split(separator: " ").first.map(String.init) ?? nickname ?? "")
            : (phoneNumber ?? "")
    }

    /// Whether the phone number is a valid US (NANP) number.
    var hasValidPhone: Bool {
        PhoneNumberValidator.isValidUSNumber(PhoneNumberValidator.sanitize(phoneNumber ?? ""))
    }
}
