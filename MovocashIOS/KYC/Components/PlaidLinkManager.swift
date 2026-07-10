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
    /// - Parameter onPresented: called once when Plaid's UI actually appears
    ///   (the `.open` event), so callers can dismiss any loading spinner exactly
    ///   then — after the token/link-token network work but before the user sees Plaid.
    func openLink(
        token: String,
        presenter: UIViewController,
        onPresented: (() -> Void)?
    ) async throws -> PlaidLinkResult
}

// MARK: - PlaidLinkManager

@MainActor
final class PlaidLinkManager: PlaidLinkManagerProtocol, TokenRefreshable {

    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    private let analytics: AnalyticsTracking
    private var handler: Handler?
    private var pendingContinuation: CheckedContinuation<PlaidLinkResult, Error>?

    // Guards against resuming the continuation more than once (Plaid may deliver
    // both onSuccess and a trailing onExit). The first callback wins.
    private var didResume = false

    // Fired once when Plaid's UI presents (the `.open` event). Lets the caller
    // dismiss its loading spinner at the right moment.
    private var onPresented: (() -> Void)?

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
        presenter: UIViewController,
        onPresented: (() -> Void)? = nil
    ) async throws -> PlaidLinkResult {

        self.onPresented = onPresented

        SecureLogger.info("[Plaid] flow start — requesting fresh auth token", category: .payment)

        // Configure the SDK before presenting the Plaid UI. configureSDK fetches a
        // fresh access token (/auth/token-access) and applies it to the SDK, so the
        // link token having been fetched seconds ago can't leave us on a stale auth token.
        try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)

        // Configure LinkKit callbacks on the main actor (before entering
        // continuation). Following the SDK's reference pattern: the success/exit
        // callbacks resolve the flow directly, and `.viewController` presentation
        // lets Plaid own (and auto-dismiss) its own UI.
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

        config.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleLinkEvent(event)
            }
        }

        // Create the Plaid handler on the main actor.
        let plaidHandler: Handler
        switch Plaid.create(config) {
        case .success(let h):
            plaidHandler = h
        case .failure(let error):
            // App-level: Link configuration/handler couldn't be created.
            SecureLogger.error("[Plaid] handler creation failed — \(error.localizedDescription)", category: .payment)
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: "handler_creation_failed"
            ])
            throw PlaidLinkError.handlerCreationFailed(error.localizedDescription)
        }

        // Retain the handler so it stays alive while the Plaid UI is presented.
        self.handler = plaidHandler
        self.didResume = false

        SecureLogger.info("[Plaid] presenting Link UI", category: .payment)

        // Present the Plaid Link UI, then suspend until onSuccess/onExit fires.
        // Plaid manages presentation and dismissal of its own view controller.
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            plaidHandler.open(presentUsing: .viewController(presenter))
        }
    }

    // MARK: - LinkKit Callbacks

    /// Every Plaid lifecycle event. This is the primary debugging signal: it
    /// traces exactly which step the user reached (OPEN, SELECT_INSTITUTION,
    /// TRANSITION_VIEW, SUBMIT_*, HANDOFF, ERROR, EXIT…) and surfaces error
    /// codes/messages, request IDs and the institution — so a device-specific
    /// problem (OAuth handoff, MFA, institution outage) can be told apart from
    /// an app-level one. Error-bearing events log at error level.
    private func handleLinkEvent(_ event: LinkEvent) {
        let meta = event.metadata
        var fields: [String] = ["event=\(event.eventName)", "session=\(meta.linkSessionID)"]
        if let view = meta.viewName            { fields.append("view=\(view)") }
        if let institution = meta.institutionName { fields.append("institution=\(institution)") }
        if let selection = meta.selection      { fields.append("selection=\(selection)") }
        if let mfa = meta.mfaType              { fields.append("mfa=\(mfa)") }
        if let request = meta.requestID        { fields.append("request=\(request)") }
        if let status = meta.exitStatus        { fields.append("exitStatus=\(status)") }
        if let code = meta.errorCode           { fields.append("errorCode=\(code)") }
        if let message = meta.errorMessage     { fields.append("errorMessage=\(message)") }

        let line = "[Plaid] " + fields.joined(separator: " ")
        if meta.errorCode != nil || meta.errorMessage != nil {
            SecureLogger.error(line, category: .payment)
        } else {
            SecureLogger.debug(line, category: .payment)
        }

        if case .open = event.eventName {
            analytics.log(AnalyticsEvent.plaidLinkStarted)
            // Plaid is now on screen — let the caller drop its loading spinner.
            onPresented?()
            onPresented = nil
        }
    }

    /// User completed Link. Parse the metadata and resolve the flow.
    private func handleLinkSuccess(_ linkSuccess: LinkSuccess) {
        let meta = linkSuccess.metadata
        SecureLogger.info(
            "[Plaid] onSuccess — institution=\(meta.institution.name) accounts=\(meta.accounts.count) session=\(meta.linkSessionID)",
            category: .payment
        )

        guard !didResume, let continuation = pendingContinuation else {
            SecureLogger.warning("[Plaid] onSuccess ignored — flow already resolved", category: .payment)
            return
        }
        didResume = true
        pendingContinuation = nil
        defer { cleanup() }

        do {
            let result = try Self.parseMetadata(from: linkSuccess)
            analytics.log(AnalyticsEvent.plaidLinkSuccess, params: [
                AnalyticsParam.institutionName: result.metadata.institution.name,
                AnalyticsParam.count: result.metadata.accounts.count
            ])
            continuation.resume(returning: result)
        } catch {
            // App-level: Plaid succeeded but its metadata didn't match our schema.
            SecureLogger.error("[Plaid] metadata parse failed — \(error.localizedDescription)", category: .payment)
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: "metadata_parse_failed"
            ])
            continuation.resume(throwing: PlaidLinkError.metadataParseFailed)
        }
    }

    /// User exited Link (cancel) or Plaid surfaced a terminal error. Logs the
    /// full exit metadata so the cause is identifiable, then resolves the flow.
    private func handleLinkExit(_ linkExit: LinkExit) {
        logExit(linkExit)

        guard !didResume, let continuation = pendingContinuation else {
            SecureLogger.warning("[Plaid] onExit ignored — flow already resolved", category: .payment)
            return
        }
        didResume = true
        pendingContinuation = nil
        defer { cleanup() }

        if let error = linkExit.error {
            // A real error — surface its message to the caller (shows an alert).
            analytics.log(AnalyticsEvent.plaidLinkExited, params: [
                AnalyticsParam.errorCode: "\(error.errorCode)"
            ])
            continuation.resume(throwing: PlaidLinkError.linkExited(error.errorMessage))
        } else {
            // Plain user cancel — resolved silently by the caller (no alert).
            analytics.log(AnalyticsEvent.plaidLinkExited, params: [
                AnalyticsParam.errorCode: "user_cancelled"
            ])
            continuation.resume(throwing: PlaidLinkError.linkExited(nil))
        }
    }

    /// Structured log of a Link exit. Error exits log at error level with the
    /// Plaid error code/message; clean cancels log at info level.
    private func logExit(_ linkExit: LinkExit) {
        let meta = linkExit.metadata
        var fields: [String] = []
        if let status = meta.status            { fields.append("status=\(status)") }
        if let institution = meta.institution?.name { fields.append("institution=\(institution)") }
        if let session = meta.linkSessionID    { fields.append("session=\(session)") }
        if let request = meta.requestID        { fields.append("request=\(request)") }

        if let error = linkExit.error {
            fields.append("errorCode=\(error.errorCode)")
            fields.append("errorMessage=\(error.errorMessage)")
            if let display = error.displayMessage { fields.append("display=\(display)") }
            SecureLogger.error("[Plaid] onExit (error) " + fields.joined(separator: " "), category: .payment)
        } else {
            SecureLogger.info("[Plaid] onExit (user cancelled) " + fields.joined(separator: " "), category: .payment)
        }
    }

    private func cleanup() {
        handler = nil
        pendingContinuation = nil
        didResume = false
        onPresented = nil
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

