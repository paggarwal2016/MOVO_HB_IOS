//
//  PlaidLinkManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 07/04/26.
//

import Foundation
import LinkKit
import MobileBankingSDK
import UIKit

// MARK: - PlaidLinkManagerProtocol

@MainActor
protocol PlaidLinkManagerProtocol {
    func openLink(token: String, presenter: UIViewController) async throws -> PlaidLinkResult
}

// MARK: - PlaidLinkManager

@MainActor
final class PlaidLinkManager: PlaidLinkManagerProtocol, TokenRefreshable {

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    private let analytics: AnalyticsTracking
    private var handler: Handler?
    private var pendingContinuation: CheckedContinuation<PlaidLinkResult, Error>?

    init(
        network: NetworkServiceProtocol,
        keychain: KeychainManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.keychain = keychain
        self.analytics = analytics ?? AnalyticsManager.shared
    }

    /// Presents the Plaid Link UI and returns the parsed result on success.
    /// The caller is responsible for fetching the link token beforehand.
    func openLink(
        token: String,
        presenter: UIViewController
    ) async throws -> PlaidLinkResult {

        // Ensure the SDK has a fresh auth token before presenting the Plaid UI.
        // The link token may have been fetched seconds ago, but the auth token
        // could have expired in the background.
        let freshToken = try await freshAccessToken()
        MobileBankingSDK.updateAuthToken(freshToken)

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
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: error.localizedDescription
            ])
            throw PlaidLinkError.handlerCreationFailed(error.localizedDescription)
        }

        // Retain the handler so it stays alive while the Plaid UI is presented.
        self.handler = plaidHandler
        analytics.log(AnalyticsEvent.plaidLinkStarted)

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
            analytics.log(AnalyticsEvent.plaidLinkSuccess, params: [
                AnalyticsParam.institutionName: result.metadata.institution.name,
                AnalyticsParam.count: result.metadata.accounts.count
            ])
            continuation.resume(returning: result)
        } catch {
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: "metadata_parse_failed"
            ])
            continuation.resume(throwing: PlaidLinkError.metadataParseFailed)
        }
    }

    private func handleLinkExit(_ linkExit: LinkExit) {
        defer { cleanup() }
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil

        let message = linkExit.error?.localizedDescription
        analytics.log(AnalyticsEvent.plaidLinkExited, params: [
            AnalyticsParam.errorCode: message ?? "user_cancelled"
        ])
        continuation.resume(throwing: PlaidLinkError.linkExited(message))
    }

    private func cleanup() {
        handler = nil
        pendingContinuation = nil
    }

    // MARK: - Token Management

    /// Fetches a fresh access token from the server before the Plaid flow starts.
    private func freshAccessToken() async throws -> String {
        do {
            let fresh = try await performTokenRefresh()
            analytics.log(AnalyticsEvent.tokenRefreshed, params: [
                AnalyticsParam.reason: "plaid_proactive_refresh"
            ])
            return fresh
        } catch {
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: "token_refresh_failed"
            ])
            SecureLogger.error("Token refresh failed before Plaid Link: \(error.localizedDescription)", category: .payment)
            throw PlaidLinkError.tokenUnavailable
        }
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

