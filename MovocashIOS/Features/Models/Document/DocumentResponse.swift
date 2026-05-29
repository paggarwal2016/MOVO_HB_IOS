//
//  DocumentResponse.swift
//  MovocashIOS
//
//  Created by Movo Developer on 02/05/26.
//

import SwiftUI

// MARK: - Document Type

enum DocumentType: Sendable, Hashable, Identifiable {
    var id: Self { self }
    case tos
    case privacy
    case herringPrivacy
    case cardholderAgreement

    var endpoint: DocumentAPI {
        switch self {
        case .tos:                 return .tos
        case .privacy:             return .privacy
        case .herringPrivacy:      return .herringPrivacy
        case .cardholderAgreement: return .cardholderAgreement
        }
    }

    var title: String {
        switch self {
        case .tos:                 return "Account Disclosures"
        case .privacy:             return "Privacy Policy"
        case .herringPrivacy:      return "Herring Privacy Policy"
        case .cardholderAgreement: return "Cardholder Agreement"
        }
    }

    var icon: String {
        switch self {
        case .tos:                 return "doc.text.fill"
        case .privacy:             return "lock.shield.fill"
        case .herringPrivacy:      return "shield.fill"
        case .cardholderAgreement: return "signature"
        }
    }

    var iconColor: Color {
        switch self {
        case .tos:                 return .indigo
        case .privacy:             return .blue
        case .herringPrivacy:      return .teal
        case .cardholderAgreement: return .purple
        }
    }
}

// MARK: - Document Response

nonisolated struct DocumentResponse: Decodable, Sendable {
    let success: Bool
    let document: String
    let message: String

    var documentURL: URL? {
        URL(string: document)
    }
}
