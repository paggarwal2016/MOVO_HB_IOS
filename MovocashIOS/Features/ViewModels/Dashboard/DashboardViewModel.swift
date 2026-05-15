//
//  DashboardViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 14/04/26.
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var dashboard: DashboardResponse?

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol
    ) {
        self.network = network
        super.init(alertManager: alertManager)
    }

    // MARK: - Fetch Dashboard (initial load — uses perform() for loading state)

    func fetchDashboard() async {
        guard !Task.isCancelled else { return }
        do {
            dashboard = try await perform { try await network.request(DashboardAPI.dashboard) }
            await activatePrimaryVCardIfNeeded()
        } catch {
            // Error is already presented via ToastManager in perform(_:)
        }
    }

    // Silently activates the primary vcard when `is_p_vcard_activated` is "Inactive".
    // Only called from fetchDashboard — not exposed for general use.
    private func activatePrimaryVCardIfNeeded() async {
        guard let account = rawPrimaryAccount,
              account.isPVCardActivated == "Inactive" else { return }

        let pin = String(format: "%04d", Int.random(in: 0...9999))
        let request = VCardsRequest(pin: pin, accountId: account.id, userAction: "VCARD-ACTIVATE", isPrimary: true)

        do {
            let _: CreateVCardEncryptedResponse = try await network.request(
                VCardAPI.postVCards(request: request)
            )
        } catch is CancellationError {
            return
        } catch {
            SecureLogger.debug(
                "Primary vcard activation failed: \(error.localizedDescription)",
                category: .general
            )
        }
    }

    // Pull-to-refresh — does NOT call perform() so state stays idle,
    // preventing HomeTabBarView from re-rendering and cancelling the refreshable task.
    func refresh() async {
        do {
            let result: DashboardResponse = try await network.request(DashboardAPI.dashboard)
            dashboard = result
            Task.detached(priority: .background) {
                await self.activatePrimaryVCardIfNeeded()
            }
        } catch is CancellationError {
            // User dismissed the pull gesture — keep existing data silently
        } catch {
            if error.shouldShowUserFacingToast {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
        }
    }

    // MARK: - Section Accessors

    var userDetails: DashboardUserDetails? {
        dashboard?.data.compactMap { section -> DashboardUserDetails? in
            guard case .userDetails(let d) = section else { return nil }
            return d
        }.first
    }

    var primaryAccount: SavingsAccountInfo? {
        guard let account = rawPrimaryAccount else { return nil }
        return SavingsAccountInfo(dashboardAccount: account)
    }

    private var rawPrimaryAccount: DashboardAccount? {
        dashboard?.data.compactMap { section -> DashboardAccount? in
            guard case .primaryAccount(let a) = section else { return nil }
            return a
        }.first
    }

    var payAnyone: DashboardPayAnyone? {
        dashboard?.data.compactMap { section -> DashboardPayAnyone? in
            guard case .payAnyone(let p) = section else { return nil }
            return p
        }.first
    }

    var rewards: DashboardRewards? {
        dashboard?.data.compactMap { section -> DashboardRewards? in
            guard case .rewards(let r) = section else { return nil }
            return r
        }.first
    }

    var linkedAccounts: DashboardLinkedAccounts? {
        dashboard?.data.compactMap { section -> DashboardLinkedAccounts? in
            guard case .linkedAccounts(let l) = section else { return nil }
            return l
        }.first
    }

    var myCards: DashboardMyCards? {
        dashboard?.data.compactMap { section -> DashboardMyCards? in
            guard case .myCards(let m) = section else { return nil }
            return m
        }.first
    }

    func optimisticallyUpdateNickname(_ nickname: String) {
        guard var current = dashboard else { return }
        current.data = current.data.map { section in
            guard case .primaryAccount(var account) = section else { return section }
            account.nickname = nickname.isEmpty ? nil : nickname
            return .primaryAccount(account)
        }
        dashboard = current
    }

    var supportMessage: String? {
        guard let d = dashboard, d.data.isEmpty else { return nil }
        return d.message
    }

    var menuItems: [DashboardAction] {
        dashboard?.data.compactMap { section -> [DashboardAction]? in
            guard case .menu(let items) = section else { return nil }
            return items
        }.first ?? []
    }
}

// MARK: - SavingsAccountInfo Mapping

private extension SavingsAccountInfo {
    init(dashboardAccount a: DashboardAccount) {
        id = a.id
        accountNumber = a.accountNumber
        clientName = a.clientName
        status = AccountStatus(rawValue: a.status) ?? .unknown
        accountBalance = Decimal(string: a.accountBalance) ?? 0
        availableBalance = Decimal(string: a.availableBalance) ?? 0
        clientId = a.clientId
        nickname = a.nickname.flatMap { $0.isEmpty ? nil : $0 }
        isPrimary = a.isPrimary
    }
}
