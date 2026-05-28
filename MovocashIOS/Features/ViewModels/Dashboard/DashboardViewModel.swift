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
    @Published var primaryLinkedCard: VCardListResponse? = nil
    @Published var isRefreshing: Bool = false

    // MARK: - Refresh Staleness Tracking

    private(set) var lastRefreshedAt: Date = .distantPast

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
        } catch {
            // Error is already presented via ToastManager in perform(_:)
        }
    }

    // Pull-to-refresh and on-return refresh.
    // Does NOT call perform() so state stays idle,
    // preventing HomeTabBarView from re-rendering and cancelling the refreshable task.
    // isRefreshing guard ensures only one call runs at a time even when multiple
    // onChange handlers fire in the same dismissal cycle.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result: DashboardResponse = try await network.request(DashboardAPI.dashboard)
            dashboard = result
            lastRefreshedAt = Date()
        } catch is CancellationError {
            // User dismissed the pull gesture — keep existing data silently
        } catch {
            if error.shouldShowUserFacingToast {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
        }
    }

    // Refresh only when data is older than `interval` seconds.
    // Prevents API hammering when multiple triggers fire near-simultaneously
    // (e.g., tab switch + notification both fire after a payment).
    func refreshIfStale(within interval: TimeInterval = 30) async {
        guard Date().timeIntervalSince(lastRefreshedAt) > interval else { return }
        await refresh()
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
        routingNumber = a.routingNumber.flatMap { $0.isEmpty ? nil : $0 }
    }
}
