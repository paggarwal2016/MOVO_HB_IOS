//
//  DeepLinkRouter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 31/03/26.
//

import Foundation
import Combine

@MainActor
class DeepLinkRouter: ObservableObject {
    
    static let shared = DeepLinkRouter()
    private init() {}

    @Published var destination: AppDestination?
    
    enum AppDestination: Hashable {
        case dashboard
        case transactions
        case transactionDetail(id: String)
        case transferMoney
        case cardManagement
        case kycVerification
        case notifications
        case settings
    }
    
    func routeFromPush(userInfo: [AnyHashable: Any]) {
        let type     = userInfo["type"]      as? String ?? ""
        let targetId = userInfo["target_id"] as? String ?? ""
        switch type {
        case "transaction": destination = targetId.isEmpty ? .transactions : .transactionDetail(id: targetId)
        case "transfer":    destination = .transferMoney
        case "card":        destination = .cardManagement
        case "kyc":         destination = .kycVerification
        default:            destination = .notifications
        }
        // AnalyticsManager.shared.logFeatureUsed(
        SecureLogger.debug("deep_link_push_\(type)")
    }

    // MARK: - Invite universal links

    private static let inviteCodeKey = "pendingInviteCode"

    /// Invite code captured from an `/invite?code=…` universal link, persisted
    /// until it's redeemed during registration. `nil` when none is pending.
    var pendingInviteCode: String? {
        get { UserDefaults.standard.string(forKey: Self.inviteCodeKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Self.inviteCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.inviteCodeKey)
            }
        }
    }

    /// Handles an inbound universal link. Returns `true` only for a recognised
    /// Movo invite link (`https://…herringbank.com/invite?code=<6-char code>`).
    ///
    /// Invites are for prospective users: an existing (authenticated) member is
    /// informed and the code is not stored. For a new user the code is persisted
    /// and the app routes straight to `EnterInviteCodeScreen`, which autofills it
    /// from `pendingInviteCode`.
    @discardableResult
    func handle(universalLink url: URL, appState: AppState) -> Bool {
        guard
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            comps.host?.hasSuffix("herringbank.com") == true,
            comps.path == "/invite",
            let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
            Self.isValidInviteCode(code)
        else {
            return false
        }

        SecureLogger.info("Invite deeplink received", category: .general)

        guard !appState.isAuthenticated else {
            ToastManager.shared.show(
                "You're already a Movo member — invites are for new users.",
                style: .info,
                position: .bottom
            )
            return true
        }

        // Persist so EnterInviteCodeScreen can autofill it on appear.
        pendingInviteCode = code

        // Route to the invite screen. On a cold launch the link arrives while the
        // splash is still showing and StartupRouter.postBootstrap is about to set
        // `flow` from `pendingDestination` — so set `pendingDestination` to win that
        // transition. When the app is already running, set `flow` directly.
        if appState.flow == .splash {
            appState.pendingDestination = .enterInviteCode
            appState.pendingContext = .getStarted
        } else {
            appState.flow = .enterInviteCode
        }
        // TODO: apply `pendingInviteCode` during registration (redemption API).
        return true
    }

    /// Consumes the pending invite code (call after it's been redeemed).
    func consumePendingInviteCode() -> String? {
        let code = pendingInviteCode
        pendingInviteCode = nil
        return code
    }

    /// A valid code is exactly 6 alphanumeric characters (matches the sender's generator).
    static func isValidInviteCode(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }
}
