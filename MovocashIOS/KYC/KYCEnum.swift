//
//  KYCEnum.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import Foundation

// MARK: - KYC Result

enum KYCResult {
    case success
    case failed(Error)
}

// MARK: - KYC Errors

enum KYCError: LocalizedError, Equatable {
    
    case notConfigured
    case noPresenter
    case cancelled
    case sdkError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Verification system not ready. Please try again."
        case .noPresenter:
            return "Unable to start verification."
        case .cancelled:
            return "Verification was cancelled."
        case .sdkError(let message):
            return message
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}


// MARK: - PlaidLinkError

enum PlaidLinkError: LocalizedError {
    case noPresenter
    case handlerCreationFailed(String)
    case linkExited(String?)
    case metadataParseFailed
    case tokenUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noPresenter:
            return "Unable to present bank linking flow."
        case .handlerCreationFailed(let reason):
            return "Failed to initialize bank link: \(reason)"
        case .linkExited(let message):
            return message ?? "Bank linking was cancelled."
        case .metadataParseFailed:
            return "Failed to process bank account data."
        case .tokenUnavailable:
            return "Authentication token unavailable. Please log in again."
        }
    }
}

// MARK: - PlaidLinkResult

struct PlaidLinkResult {
    let publicToken: String
    let metadata: LinkPlaidLinkMetadata
}



// MARK: - Private Metadata JSON Models

struct PlaidMetadataJSON: Decodable {
    let institution: PlaidInstitutionJSON?
    let accounts: [PlaidAccountJSON]
    let link_session_id: String?
    
    enum CodingKeys: String, CodingKey {
        case institution
        case accounts
        case link_session_id
        case linkSessionID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        institution = try container.decodeIfPresent(PlaidInstitutionJSON.self, forKey: .institution)
        accounts = try container.decodeIfPresent([PlaidAccountJSON].self, forKey: .accounts) ?? []
        link_session_id =
        try container.decodeIfPresent(String.self, forKey: .link_session_id)
        ?? container.decodeIfPresent(String.self, forKey: .linkSessionID)
    }
}

struct PlaidInstitutionJSON: Decodable {
    let institution_id: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case institution_id
        case institutionID
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        institution_id =
        try container.decodeIfPresent(String.self, forKey: .institution_id)
        ?? container.decodeIfPresent(String.self, forKey: .institutionID)
        ?? container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
}

struct PlaidAccountJSON: Decodable {
    let id: String
    let name: String?
    let mask: String?
    let type: String?
    let subtype: String?
    let verification_status: String?
    let class_type: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mask
        case type
        case subtype
        case verification_status
        case verificationStatus
        case class_type
        case classType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        mask = try container.decodeIfPresent(String.self, forKey: .mask)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        verification_status =
        try container.decodeIfPresent(String.self, forKey: .verification_status)
        ?? container.decodeIfPresent(String.self, forKey: .verificationStatus)
        class_type =
        try container.decodeIfPresent(String.self, forKey: .class_type)
        ?? container.decodeIfPresent(String.self, forKey: .classType)
    }
}
