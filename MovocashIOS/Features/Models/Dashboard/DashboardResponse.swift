//
//  DashboardResponse.swift
//  MovocashIOS
//
//  Created by Vinu on 14/04/26.
//

import Foundation

// MARK: - Top-Level Response

nonisolated struct DashboardResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    var data: [DashboardSection]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decode(Bool.self, forKey: .success)
        message = try c.decode(String.self, forKey: .message)
        data = (try? c.decode([DashboardSection].self, forKey: .data)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case success, message, data }
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
    case unknown
}

extension DashboardSection: Decodable {
    private enum CodingKeys: String, CodingKey { case name, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decode(String.self, forKey: .name)
        switch name {
        case "USERDETAILS":
            self = .userDetails(try c.decode(DashboardUserDetails.self, forKey: .data))
        case "PRIMARYACCOUNT":
            self = .primaryAccount(try c.decode(DashboardAccount.self, forKey: .data))
        case "PAYANYONE":
            self = .payAnyone(try c.decode(DashboardPayAnyone.self, forKey: .data))
        case "REWARDS":
            self = .rewards(try c.decode(DashboardRewards.self, forKey: .data))
        case "LINKEDACCOUNTS":
            self = .linkedAccounts(try c.decode(DashboardLinkedAccounts.self, forKey: .data))
        case "MYCARDS":
            self = .myCards(try c.decode(DashboardMyCards.self, forKey: .data))
        case "MENU":
            self = .menu(try c.decode([DashboardAction].self, forKey: .data))
        default:
            self = .unknown
        }
    }
}

// MARK: - USERDETAILS

nonisolated struct DashboardUserDetails: Decodable, Sendable {
    let firstName: String
    let lastName: String
    let profilePicture: String
    let email: String
    let phone: String
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

    private enum CodingKeys: String, CodingKey {
        case id, accountNumber, clientName, status, accountBalance
        case availableBalance, clientId, nickname, isPrimary, actions
        case isPVCardActivated = "is_p_vcard_activated"
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
        accountId = try c.decode(Int.self, forKey: .accountId)
        customerId = try c.decode(Int.self, forKey: .customerId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        favContactList = try c.decodeIfPresent([RecordContact].self, forKey: .favContactList) ?? []
        actions = try c.decodeIfPresent([DashboardAction].self, forKey: .actions) ?? []
    }
}

// MARK: - REWARDS

nonisolated struct DashboardRewards: Decodable, Sendable {
    let accountId: Int
    let customerId: Int
    let title: String
    let totalCoins: Int
    let actions: [DashboardAction]
}

// MARK: - LINKEDACCOUNTS

nonisolated struct DashboardLinkedAccounts: Decodable, Sendable {
    let accountId: Int?
    let customerId: Int?
    let title: String
    let description: String
    let linkedAccounts: [DashboardLinkedAccount]?
    let actions: [DashboardAction]
}

nonisolated struct DashboardLinkedAccount: Decodable, Sendable {
    let achAccountId: Int
    let institutionName: String
    let institutionLogo: String
    let accountName: String
    let accountNumber: String
    let plaidAccountId: String
    let plaidAccountBalance: String
    let isDefault: Bool
    let isPlaidLoginRequired: Bool
}

// MARK: - MYCARDS

nonisolated struct DashboardMyCards: Decodable, Sendable {
    let title: String
    let description: String
    let actions: [DashboardAction]
}

// MARK: - Shared

nonisolated struct DashboardAction: Decodable, Sendable {
    let label: String
    let action: String
}

