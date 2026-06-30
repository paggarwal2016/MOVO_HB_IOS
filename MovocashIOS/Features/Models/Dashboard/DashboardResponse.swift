//
//  DashboardResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 14/04/26.
//

import Foundation

// MARK: - Top-Level Response

nonisolated struct DashboardResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    var data: [DashboardSection]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = c.decodeLossyBool(forKey: .success, defaultIfMissing: true)
        message = c.decodeLossyString(forKey: .message)
        data = try Self.decodeSectionsPreservingOthers(from: c)
    }

    private enum CodingKeys: String, CodingKey { case success, message, data }

    /// Decodes dashboard rows independently: one bad blob never drops the whole dashboard.
    private static func decodeSectionsPreservingOthers(
        from c: KeyedDecodingContainer<CodingKeys>
    ) throws -> [DashboardSection] {
        guard c.contains(.data), try !(c.decodeNil(forKey: .data)) else { return [] }

        var rows = try c.nestedUnkeyedContainer(forKey: .data)
        let decoderForTypedSubtrees = JSONDecoder.dashboardDashboardTypedSubtreeDecoder
        var sections: [DashboardSection] = []
        sections.reserveCapacity(12)

        while !rows.isAtEnd {
            if let envelope = try? rows.decode(DashboardEnvelope.self) {
                sections.append(
                    DashboardSection.resolved(
                        name: envelope.name,
                        dataJSON: envelope.data,
                        subtreeDecoder: decoderForTypedSubtrees
                    )
                )
            } else {
                /// Consume malformed element(s) rather than poisoning the remainder of `data`.
                if (try? rows.decode(DiscardOneJSON.self)) == nil {
                    break
                }
            }
        }
        return sections
    }
}

// MARK: - Per-row envelope (decoupled list parsing from typed section payloads)

nonisolated fileprivate struct DashboardEnvelope: Decodable, Sendable {
    let name: String
    let data: DiscardOneJSON

    private enum CodingKeys: String, CodingKey { case name, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        data = try c.decode(DiscardOneJSON.self, forKey: .data)
    }
}

nonisolated fileprivate struct DiscardOneJSON: Codable, Sendable {
    private let boxed: DashboardJSONValue

    init(from decoder: Decoder) throws {
        boxed = try DashboardJSONValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try boxed.encode(to: encoder)
    }
}

nonisolated fileprivate indirect enum DashboardJSONValue: Codable, Sendable {
    case object([String: DashboardJSONValue])
    case array([DashboardJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    nonisolated fileprivate enum DynamicCodingKey: CodingKey {
        case string(String)
        case int(Int)

        var stringValue: String {
            switch self {
            case .string(let s): return s
            case .int(let i): return String(i)
            }
        }

        var intValue: Int? {
            if case let .int(i) = self { return i }
            return nil
        }

        init?(stringValue: String) { self = .string(stringValue) }
        init?(intValue: Int) { self = .int(intValue) }
    }

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dict: [String: DashboardJSONValue] = [:]
            dict.reserveCapacity(keyed.allKeys.count)
            for key in keyed.allKeys {
                let rawKey = key.stringValue
                if try keyed.decodeNil(forKey: key) {
                    dict[rawKey] = .null
                } else {
                    dict[rawKey] = try keyed.decode(DashboardJSONValue.self, forKey: key)
                }
            }
            self = .object(dict)
            return
        }

        if var unkeyed = try? decoder.unkeyedContainer() {
            var elements: [DashboardJSONValue] = []
            while !unkeyed.isAtEnd {
                elements.append(try unkeyed.decode(DashboardJSONValue.self))
            }
            self = .array(elements)
            return
        }

        let sc = try decoder.singleValueContainer()
        if sc.decodeNil() {
            self = .null
            return
        }
        if let s = try? sc.decode(String.self) {
            self = .string(s)
        } else if let d = try? sc.decode(Double.self) {
            self = .number(d)
        } else if let b = try? sc.decode(Bool.self) {
            self = .bool(b)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON fragment")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var c = encoder.singleValueContainer()
            try c.encodeNil()
        case let .bool(b):
            var c = encoder.singleValueContainer()
            try c.encode(b)
        case let .number(n):
            var c = encoder.singleValueContainer()
            try c.encode(n)
        case let .string(s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case let .array(elements):
            var c = encoder.unkeyedContainer()
            for element in elements {
                try c.encode(element)
            }
        case let .object(dict):
            var c = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dict {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try c.encode(value, forKey: codingKey)
            }
        }
    }
}

extension JSONEncoder {
    nonisolated fileprivate static var dashboardTypedSubtreeEncoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }
}

extension JSONDecoder {
    /// Used only to re-materialize subtree JSON into Codable dashboards models (strings for dates etc.).
    nonisolated static var dashboardDashboardTypedSubtreeDecoder: JSONDecoder {
        JSONDecoder()
    }
}

// MARK: - Section Enum

enum DashboardSection: Sendable {
    case userDetails(DashboardUserDetails)
    case primaryAccount(DashboardAccount)
    case payAnyone(DashboardPayAnyone)
    case rewards(DashboardRewards)
    case linkedAccounts(DashboardLinkedAccounts)
    case myCards(DashboardMyCards)
    case menu([DashboardAction])
    case inviteAFriend(DashboardInviteAFriend)
    case unknown
}

extension DashboardSection {
    nonisolated fileprivate static func resolved(
        name rawName: String,
        dataJSON: DiscardOneJSON,
        subtreeDecoder decoder: JSONDecoder
    ) -> DashboardSection {
        let name = rawName.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .unknown }

        guard let blob = try? JSONEncoder.dashboardTypedSubtreeEncoder.encode(dataJSON) else {
            return .unknown
        }

        func decoded<T: Decodable>(_ type: T.Type) -> T? {
            try? decoder.decode(T.self, from: blob)
        }

        switch name {
        case "USERDETAILS":
            guard let v = decoded(DashboardUserDetails.self) else { return .unknown }
            return .userDetails(v)
        case "PRIMARYACCOUNT":
            guard let v = decoded(DashboardAccount.self) else { return .unknown }
            return .primaryAccount(v)
        case "PAYANYONE":
            guard let v = decoded(DashboardPayAnyone.self) else { return .unknown }
            return .payAnyone(v)
        case "REWARDS":
            guard let v = decoded(DashboardRewards.self) else { return .unknown }
            return .rewards(v)
        case "LINKEDACCOUNTS":
            guard let v = decoded(DashboardLinkedAccounts.self) else { return .unknown }
            return .linkedAccounts(v)
        case "MYCARDS":
            guard let v = decoded(DashboardMyCards.self) else { return .unknown }
            return .myCards(v)
        case "MENU":
            guard let v = decoded([DashboardAction].self) else { return .unknown }
            return .menu(v)
        case "INVITE-A-FRIEND":
            guard let v = decoded(DashboardInviteAFriend.self) else { return .unknown }
            return .inviteAFriend(v)
        default:
            return .unknown
        }
    }
}

// MARK: - INVITE-A-FRIEND

nonisolated struct DashboardInviteAFriend: Decodable, Sendable {
    let title: String
    let description: String?
    let invitees: [Invitee]?
    let totalInvites: Int?
    let actions: [DashboardAction]?

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case invitees
        case totalInvites = "total_invites"
        case actions
    }

    nonisolated struct Invitee: Decodable, Sendable {
        let inviteePhone: String?
        let nickname: String?

        private enum CodingKeys: String, CodingKey {
            case inviteePhone = "invitee_phone"
            case nickname
        }
    }
}

// MARK: - USERDETAILS

nonisolated struct DashboardUserDetails: Decodable, Sendable {
    let firstName: String
    let lastName: String
    let profilePicture: String
    let email: String?
    let phone: String?
    let customerId: Int
    let cipRequired: Bool
    let cipAllowed: Bool
    let smsVerified: Bool
    let emailVerified: Bool
    let isDeactivated: Bool
    let isTwoFactorEnabled: Bool
    let isPlaidAuthRequired: Bool
    let isAdditionalKycRequired: Bool
    let addressLine1: String
    let addressLine2: String?
    let city: String
    let state: String
    let zip: String
    let driversLicenseState: String?
    let driversLicenseNumber: String?
    let smsVerifiedDate: String?
    let username: String

    private enum CodingKeys: String, CodingKey {
        case firstName, lastName, profilePicture, email, phone, customerId
        case cipRequired, cipAllowed, smsVerified, emailVerified
        case isDeactivated, isTwoFactorEnabled, isPlaidAuthRequired, isAdditionalKycRequired
        case addressLine1, addressLine2, city, state, zip
        case driversLicenseState, driversLicenseNumber, smsVerifiedDate, username
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = c.decodeLossyString(forKey: .firstName)
        lastName = c.decodeLossyString(forKey: .lastName)
        profilePicture = c.decodeLossyString(forKey: .profilePicture)
        email = try c.decodeLossyOptionalString(forKey: .email)
        phone = try c.decodeLossyOptionalString(forKey: .phone)
        customerId = c.decodeLossyInt(forKey: .customerId)
        cipRequired = c.decodeLossyBool(forKey: .cipRequired)
        cipAllowed = c.decodeLossyBool(forKey: .cipAllowed)
        smsVerified = c.decodeLossyBool(forKey: .smsVerified)
        emailVerified = c.decodeLossyBool(forKey: .emailVerified)
        isDeactivated = c.decodeLossyBool(forKey: .isDeactivated)
        isTwoFactorEnabled = c.decodeLossyBool(forKey: .isTwoFactorEnabled)
        isPlaidAuthRequired = c.decodeLossyBool(forKey: .isPlaidAuthRequired)
        isAdditionalKycRequired = c.decodeLossyBool(forKey: .isAdditionalKycRequired)
        addressLine1 = c.decodeLossyString(forKey: .addressLine1)
        addressLine2 = try c.decodeLossyOptionalString(forKey: .addressLine2)
        city = c.decodeLossyString(forKey: .city)
        state = c.decodeLossyString(forKey: .state)
        zip = c.decodeLossyString(forKey: .zip)
        driversLicenseState = try c.decodeLossyOptionalString(forKey: .driversLicenseState)
        driversLicenseNumber = try c.decodeLossyOptionalString(forKey: .driversLicenseNumber)
        smsVerifiedDate = try c.decodeLossyOptionalString(forKey: .smsVerifiedDate)
        username = c.decodeLossyString(forKey: .username)
    }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}

// MARK: - PRIMARYACCOUNT

nonisolated struct DashboardAccount: Decodable, Sendable {
    let id: Int
    let accountNumber: String
    let clientName: String
    let status: String
    let accountBalance: String
    let availableBalance: String
    let clientId: Int
    var nickname: String?
    let isPrimary: Bool
    let actions: [DashboardAction]
    let isPVCardActivated: String?
    let routingNumber: String?

    private enum CodingKeys: String, CodingKey {
        case id, accountNumber, clientName, status, accountBalance
        case availableBalance, clientId, nickname, isPrimary, actions
        case isPVCardActivated = "is_p_vcard_activated"
        case routingNumber
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        accountNumber = c.decodeLossyString(forKey: .accountNumber)
        clientName = c.decodeLossyString(forKey: .clientName)
        status = c.decodeLossyString(forKey: .status)
        accountBalance = c.decodeLossyString(forKey: .accountBalance)
        availableBalance = c.decodeLossyString(forKey: .availableBalance)
        clientId = c.decodeLossyInt(forKey: .clientId)
        nickname = try c.decodeLossyOptionalString(forKey: .nickname)
        isPrimary = c.decodeLossyBool(forKey: .isPrimary, defaultIfMissing: true)
        actions = try c.decodeLossyDashboardActionArray(forKey: .actions)
        isPVCardActivated = try c.decodeLossyOptionalString(forKey: .isPVCardActivated)
        routingNumber = try c.decodeLossyOptionalString(forKey: .routingNumber)
    }
}

// MARK: - PAYANYONE

nonisolated struct DashboardPayAnyone: Decodable, Sendable {
    let accountId: Int
    let customerId: Int
    let title: String?
    let description: String?
    let favContactList: [RecordContact]
    let actions: [DashboardAction]

    private enum CodingKeys: String, CodingKey {
        case accountId, customerId, title, description, favContactList, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accountId = c.decodeLossyInt(forKey: .accountId)
        customerId = c.decodeLossyInt(forKey: .customerId)
        title = try c.decodeLossyOptionalString(forKey: .title)
        description = try c.decodeLossyOptionalString(forKey: .description)
        favContactList = try c.decodeLossyContactArray(forKey: .favContactList)
        actions = try c.decodeLossyDashboardActionArray(forKey: .actions)
    }
}

// MARK: - REWARDS

nonisolated struct DashboardRewards: Decodable, Sendable {
    let accountId: Int
    let customerId: Int
    let title: String
    let totalCoins: Int
    let actions: [DashboardAction]

    private enum CodingKeys: String, CodingKey {
        case accountId, customerId, title, totalCoins, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accountId = c.decodeLossyInt(forKey: .accountId)
        customerId = c.decodeLossyInt(forKey: .customerId)
        title = c.decodeLossyString(forKey: .title)
        totalCoins = c.decodeLossyInt(forKey: .totalCoins)
        actions = try c.decodeLossyDashboardActionArray(forKey: .actions)
    }
}

// MARK: - LINKEDACCOUNTS

nonisolated struct DashboardLinkedAccounts: Decodable, Sendable {
    let accountId: Int?
    let customerId: Int?
    let title: String
    let description: String
    let linkedAccounts: [ACHAccount]?
    let actions: [DashboardAction]

    private enum CodingKeys: String, CodingKey {
        case accountId, customerId, title, description, linkedAccounts, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try decodeOptionalPositiveInt(container: c, key: .accountId)
        customerId = try decodeOptionalPositiveInt(container: c, key: .customerId)
        title = c.decodeLossyString(forKey: .title)
        description = c.decodeLossyString(forKey: .description)
        linkedAccounts = try c.decodeLossyOptionalLinkedAccountArray(forKey: .linkedAccounts)
        actions = try c.decodeLossyDashboardActionArray(forKey: .actions)
    }
}

// MARK: - MYCARDS

nonisolated struct DashboardMyCards: Decodable, Sendable {
    let title: String
    let description: String
    let actions: [DashboardAction]
    /// Sealed-box ciphertext (base64) carrying the user's `[VCardListResponse]`.
    /// Decrypted by DashboardViewModel via SealedCryptoService.
    let encryptedData: String?

    private enum CodingKeys: String, CodingKey {
        case title, description, actions, encryptedData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.decodeLossyString(forKey: .title)
        description = c.decodeLossyString(forKey: .description)
        actions = try c.decodeLossyDashboardActionArray(forKey: .actions)
        encryptedData = try? c.decodeIfPresent(String.self, forKey: .encryptedData)
    }
}

// MARK: - Shared action row

nonisolated struct DashboardAction: Decodable, Sendable {
    let label: String
    let action: String

    private enum CodingKeys: String, CodingKey { case label, action }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = c.decodeLossyString(forKey: .label)
        action = c.decodeLossyString(forKey: .action)
    }
}

// MARK: - Loose decoding helpers (dashboard payload variability)

nonisolated fileprivate extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key, default defaultValue: String = "") -> String {
        if let raw = try? decodeIfPresent(String.self, forKey: key) {
            return raw
        }
        if let raw = try? decodeIfPresent(Bool.self, forKey: key) {
            return raw.description
        }
        if let raw = try? decodeIfPresent(Int.self, forKey: key) {
            return String(raw)
        }
        if let raw = try? decodeIfPresent(Double.self, forKey: key), raw.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(raw))
        }
        if let raw = try? decodeIfPresent(Double.self, forKey: key) {
            return String(raw)
        }
        return defaultValue
    }

    func decodeLossyBool(forKey key: Key, defaultIfMissing defaultValue: Bool = false) -> Bool {
        guard contains(key), (try? decodeNil(forKey: key)) != true else { return defaultValue }

        if let b = try? decode(Bool.self, forKey: key) { return b }
        let s = decodeLossyString(forKey: key).lowercased()
        switch s {
        case "true", "1", "yes", "y": return true
        case "false", "0", "no", "n", "": return false
        default:
            if let i = Int(s) {
                return i != 0
            }
            return defaultValue
        }
    }

    func decodeLossyInt(forKey key: Key, default defaultValue: Int = 0) -> Int {
        do {
            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return intValue
            }
            if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
                return Int(doubleValue)
            }
        } catch {
            // Fall through — parse from string-ish forms below.
        }
        let trimmed = decodeLossyString(forKey: key).trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = Int(trimmed) {
            return parsed
        }
        let digits = trimmed.filter { $0.isNumber }
        return Int(digits) ?? defaultValue
    }

    func decodeLossyOptionalString(forKey key: Key) throws -> String? {
        guard contains(key) else { return nil }
        guard try !(decodeNil(forKey: key)) else { return nil }

        let coalesced = decodeLossyString(forKey: key)
        let trimmed = coalesced.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func decodeLossyDashboardActionArray(forKey key: Key) throws -> [DashboardAction] {
        try decodeLossyElementArray(forKey: key)
    }

    func decodeLossyContactArray(forKey key: Key) throws -> [RecordContact] {
        try decodeLossyElementArray(forKey: key)
    }

    func decodeLossyOptionalLinkedAccountArray(forKey key: Key) throws -> [ACHAccount]? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        let array: [ACHAccount] = try decodeLossyElementArray(forKey: key)
        return array
    }

    func decodeLossyElementArray<T: Decodable>(forKey key: Key) throws -> [T] {
        guard contains(key), try !(decodeNil(forKey: key)) else { return [] }

        guard var unkeyed = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var out: [T] = []
        while !unkeyed.isAtEnd {
            if let item = try? unkeyed.decode(T.self) {
                out.append(item)
            } else if (try? unkeyed.decode(DiscardOneJSON.self)) == nil {
                break
            }
        }
        return out
    }
}

/// Matches optional dashboard IDs that occasionally arrive quoted or blank.
nonisolated fileprivate func decodeOptionalPositiveInt<K: CodingKey>(
    container c: KeyedDecodingContainer<K>,
    key: K
) throws -> Int? {
    guard c.contains(key) else { return nil }
    guard try !(c.decodeNil(forKey: key)) else { return nil }

    if let explicit = try? c.decode(Int.self, forKey: key) {
        return explicit
    }

    let s = c.decodeLossyString(forKey: key).trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty { return nil }
    return Int(s)
}
