//
//  PlaidLinkManager.swift
//  MovocashIOS
//

import Foundation
import LinkKit
import MobileBankingSDK
import UIKit

// MARK: - PlaidLinkError

enum PlaidLinkError: LocalizedError {
    case noPresenter
    case handlerCreationFailed(String)
    case linkExited(String?)
    case metadataParseFailed

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
        }
    }
}

// MARK: - PlaidLinkResult

struct PlaidLinkResult {
    let publicToken: String
    let metadata: LinkPlaidLinkMetadata
}

// MARK: - PlaidLinkManager

@MainActor
final class PlaidLinkManager {

    private var handler: Handler?
    private var pendingContinuation: CheckedContinuation<PlaidLinkResult, Error>?

    /// Presents the Plaid Link UI and returns the parsed result on success.
    /// The caller is responsible for fetching the link token beforehand.
    func openLink(
        token: String,
        presenter: UIViewController
    ) async throws -> PlaidLinkResult {

        // Configure LinkKit callbacks on the main actor (before entering continuation).
        var config = LinkTokenConfiguration(
            token: token,
            onSuccess: { [weak self] linkSuccess in
                Task { @MainActor [weak self] in
                    self?.handleLinkSuccess(linkSuccess)
                }
            }
        )

        config.onExit = { [weak self] linkExit in
            Task { @MainActor [weak self] in
                self?.handleLinkExit(linkExit)
            }
        }

        // Create the Plaid handler on the main actor.
        let plaidHandler: Handler
        switch Plaid.create(config) {
        case .success(let h):
            plaidHandler = h
        case .failure(let error):
            throw PlaidLinkError.handlerCreationFailed(error.localizedDescription)
        }

        // Retain the handler so it stays alive while the Plaid UI is presented.
        self.handler = plaidHandler

        // Present the Plaid Link UI, then suspend until a callback fires.
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            plaidHandler.open(presentUsing: .viewController(presenter))
        }
    }

    // MARK: - LinkKit Callbacks

    private func handleLinkSuccess(_ linkSuccess: LinkSuccess) {
        defer { cleanup() }
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil

        do {
            let result = try Self.parseMetadata(from: linkSuccess)
            continuation.resume(returning: result)
        } catch {
            continuation.resume(throwing: PlaidLinkError.metadataParseFailed)
        }
    }

    private func handleLinkExit(_ linkExit: LinkExit) {
        defer { cleanup() }
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil

        let message = linkExit.error?.localizedDescription
        continuation.resume(throwing: PlaidLinkError.linkExited(message))
    }

    private func cleanup() {
        handler = nil
        pendingContinuation = nil
    }

    // MARK: - Metadata Parsing

    private static func parseMetadata(from success: LinkSuccess) throws -> PlaidLinkResult {
        guard let jsonString = success.metadata.metadataJSON,
              let jsonData = jsonString.data(using: .utf8) else {
            throw PlaidLinkError.metadataParseFailed
        }

        let decoded = try JSONDecoder().decode(PlaidMetadataJSON.self, from: jsonData)

        guard let institution = decoded.institution else {
            throw PlaidLinkError.metadataParseFailed
        }

        guard let linkSessionID = decoded.link_session_id, !linkSessionID.isEmpty else {
            throw PlaidLinkError.metadataParseFailed
        }

        let accounts: [LinkPlaidAccountMetadataAccount] = try decoded.accounts.map { account in
            guard let type = account.type, !type.isEmpty else {
                throw PlaidLinkError.metadataParseFailed
            }
            guard let subtype = account.subtype, !subtype.isEmpty else {
                throw PlaidLinkError.metadataParseFailed
            }

            return LinkPlaidAccountMetadataAccount(
                id: account.id,
                name: account.name,
                mask: account.mask,
                type: type,
                subtype: subtype,
                verification_status: account.verification_status,
                institutionName: institution.name,
                class_type: account.class_type
            )
        }

        guard !accounts.isEmpty else {
            throw PlaidLinkError.metadataParseFailed
        }

        let metadata = LinkPlaidLinkMetadata(
            institution: LinkPlaidInstitution(
                institution_id: institution.institution_id,
                name: institution.name
            ),
            accounts: accounts,
            link_session_id: linkSessionID
        )

        guard !success.publicToken.isEmpty else {
            throw PlaidLinkError.metadataParseFailed
        }

        return PlaidLinkResult(publicToken: success.publicToken, metadata: metadata)
    }
}

// MARK: - Private Metadata JSON Models

private struct PlaidMetadataJSON: Decodable {
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

private struct PlaidInstitutionJSON: Decodable {
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

private struct PlaidAccountJSON: Decodable {
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
