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
    private var session: PlaidLinkSession?
    private var pendingContinuation: CheckedContinuation<PlaidLinkResult, Error>?
    
    // Guards against resuming the continuation more than once (Plaid may deliver
    // both onSuccess and a trailing onExit). The first callback wins.
    private var didResume = false

    /// True from the moment a link flow starts until it fully resolves. Guards
    /// `openLink` against re-entrancy (double-tap, or a retry during the
    /// `configureSDK` await) that would otherwise orphan the in-flight continuation
    /// — hanging its awaiting task — and open a second Plaid UI. Set/cleared
    /// synchronously on the main actor.
    private var isLinkFlowActive = false
    
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

        // Re-entrancy guard — reject a duplicate flow while one is active. Set
        // synchronously before the first `await`, so two concurrent callers can't
        // both pass (which would orphan the first continuation and open two Plaid
        // UIs). The `defer` clears it on every exit path — early throw or resolution.
        guard !isLinkFlowActive else {
            SecureLogger.warning("[Plaid] openLink ignored — a link flow is already in progress", category: .payment)
            throw PlaidLinkError.linkInProgress
        }
        isLinkFlowActive = true
        defer { isLinkFlowActive = false }

        self.onPresented = onPresented

        SecureLogger.info("[Plaid] flow start — requesting fresh auth token", category: .payment)
        
        // Configure the SDK before presenting the Plaid UI. configureSDK fetches a
        // fresh access token (/auth/token-access) and applies it to the SDK, so the
        // link token having been fetched seconds ago can't leave us on a stale auth token.
        try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
        
        let config = LinkTokenConfiguration(
            token: token,
            onSuccess: { [weak self] linkSuccess in
                Task { @MainActor [weak self] in
                    self?.handleLinkSuccess(linkSuccess)
                }
            },
            onExit: { [weak self] linkExit in
                Task { @MainActor [weak self] in
                    self?.handleLinkExit(linkExit)
                }
            },
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleLinkEvent(event)
                }
            },
            onLoad: {
                SecureLogger.info("[Plaid] Link ready (onLoad)", category: .payment)
            }
        )
        
        let plaidSession: PlaidLinkSession
        do {
            plaidSession = try Plaid.createPlaidLinkSession(configuration: config)
        } catch {
            SecureLogger.error("[Plaid] session creation failed — \(error.localizedDescription)", category: .payment)
            analytics.log(AnalyticsEvent.plaidLinkFailed, params: [
                AnalyticsParam.errorCode: "handler_creation_failed"
            ])
            throw PlaidLinkError.handlerCreationFailed(error.localizedDescription)
        }
        self.session = plaidSession
        self.didResume = false
        
        SecureLogger.info("[Plaid] presenting Link UI", category: .payment)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            plaidSession.open(using: .viewController(presenter))
        }
    }
    
    // MARK: - LinkKit Callbacks
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
                AnalyticsParam.reason: "plaid_widget",
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
        session = nil
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

