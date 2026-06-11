//
//  DashboardViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 14/04/26.
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var dashboard: DashboardResponse?
    @Published var primaryLinkedCard: VCardListResponse? = nil
    @Published var isRefreshing: Bool = false

    // MARK: - VCard State (derived from the MYCARDS encryptedData payload)

    /// Non-primary cards, used by the card carousel and downstream screens.
    @Published var apiCards: [VCardListResponse] = []
    /// Disabled (deleted) cards — `enabled == false`. Surfaced in Profile.
    @Published var deletedCards: [VCardListResponse] = []
    /// True once a dashboard load has resolved the cards payload (drives skeleton vs content).
    @Published var hasLoadedCards: Bool = false
    
    @Published var quickPayTitle: String = ""

    /// Alias kept for call sites that read `cards`.
    var cards: [VCardListResponse] { apiCards }

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
            decryptAndSplitCards()
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
            decryptAndSplitCards()
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

    // MARK: - Cards (decrypt MYCARDS payload)

    /// Decrypts the MYCARDS `encryptedData` into `[VCardListResponse]` and splits it the
    /// same way `VCardViewModel.loadCards` did: the card linked to the primary account
    /// becomes `primaryLinkedCard`; the remainder populate `apiCards`.
    private func decryptAndSplitCards() {
        defer { hasLoadedCards = true }

        guard let encrypted = myCards?.encryptedData, !encrypted.isEmpty else {
            primaryLinkedCard = nil
            apiCards = []
            deletedCards = []
            return
        }

        do {
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encrypted)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[Dashboard cards decrypt]", json)
            }
#endif
            let decoded = try JSONDecoder().decode([VCardListResponse].self, from: plainData)
            deletedCards = decoded.filter { $0.enabled == false }
            let all = decoded.filter { $0.enabled == true }
            if let accountId = primaryAccount?.id,
               let matched = all.first(where: { $0.savingsAccountId == accountId }) {
                primaryLinkedCard = matched
                apiCards = all.filter { $0.savingsAccountId != accountId }
            } else {
                primaryLinkedCard = all.first
                apiCards = Array(all.dropFirst())
            }
        } catch {
            // Leave previously loaded cards in place on a transient decrypt/decode failure.
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
        routingNumber = a.routingNumber.flatMap { $0.isEmpty ? nil : $0 }
    }
}
