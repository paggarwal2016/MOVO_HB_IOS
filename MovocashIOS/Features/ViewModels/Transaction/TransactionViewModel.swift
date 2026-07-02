//
//  TransactionViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import Foundation
import Combine

@MainActor
final class TransactionViewModel: BaseViewModel {

    // MARK: - Published State

    @Published var transactions: [TransactionItem] = []
    @Published var searchText: String = ""
    @Published public var searchQuery: String = ""
    public var totalCount: Int { transactions.count }

    /// Result of the most recent `checkIntent` call.
    /// `nil` while the check is in-flight or if it has not yet been called.
    @Published var checkIntentResult: CheckIntentResponse? = nil

    /// True while a subsequent page is being appended (drives the bottom spinner).
    /// Distinct from `state == .loading`, which is reserved for the first page.
    @Published private(set) var isLoadingMore = false

    /// Total number of records on the server for the active filter (from `metadata.totalRecords`).
    /// `nil` if the server omitted it.
    @Published private(set) var totalRecords: Int? = nil

    /// Account balances from the latest transactions response.
    @Published private(set) var balance: Decimal = 0
    @Published private(set) var settledBalance: Decimal = 0

    // MARK: - Computed

    var filteredTransactions: [TransactionItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return transactions }
        return transactions.filter {
            $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query) ||
            $0.amountFormatted.lowercased().contains(query) ||
            $0.status.lowercased().contains(query)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    var groupedTransactions: [(label: String, date: Date, items: [TransactionItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.map { date, items in
            let label: String
            if calendar.isDateInToday(date)     { label = "Today" }
            else if calendar.isDateInYesterday(date) { label = "Yesterday" }
            else { label = Self.dayFormatter.string(from: date) }
            return (label: label, date: date, items: items.sorted { $0.date > $1.date })
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Dependencies

    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    // MARK: - Pagination State

    /// Page size sent as both `limit` and `max` so the two server params never disagree.
    private let pageSize = 25
    /// Number of items fetched so far — sent as the next request's `offset`.
    private var pageOffset = 0
    /// `false` once a page returns fewer than `pageSize` items (end reached).
    private var hasMorePages = true
    /// The filter for the current result set, reused (with new offset) for each page.
    private var activePageFilter: TransactionFilter?

    // MARK: - Init

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }

    // MARK: - Post Withdrawal

    func postWithdrawal(request: TransactionRequest.Withdrawal) async throws -> TransactionWithdrawalResponse {
        do {
            let response: TransactionWithdrawalResponse = try await perform {
                try await self.network.request(TransactionAPI.withdrawals(request))
            }
            analytics.log(AnalyticsEvent.withdrawalInitiated, params: [
                AnalyticsParam.accountId: request.accountId,
                AnalyticsParam.amount: request.transactionAmount,
                AnalyticsParam.savingsAccountId: request.savingsAccountId
            ])
            return response
        } catch {
            analytics.log(AnalyticsEvent.withdrawalFailed, params: [
                AnalyticsParam.accountId: request.accountId,
                AnalyticsParam.amount: request.transactionAmount
            ])
            throw error
        }
    }

    // MARK: - Load Transactions

    /// Loads the first page for `filter`, replacing the current list.
    ///
    /// - Parameter paginated: When `true` (default) the list pages in `pageSize` chunks
    ///   and `loadNextPage()` can fetch more. When `false` it fetches exactly the filter's
    ///   `limit`/`max` count once and disables infinite scroll — used for fixed previews
    ///   like "latest 10" on the card detail sheet.
    func loadTransactionsFiltered(filter: TransactionFilter, paginated: Bool = true) async {
        let count = paginated ? pageSize : (filter.limit ?? filter.max)

        var first = filter
        first.limit  = count
        first.offset = 0
        first.max    = count

        // A nil activePageFilter makes loadNextPage() a no-op (no pagination).
        activePageFilter = paginated ? first : nil
        pageOffset = 0
        hasMorePages = false

        do {
            let response: TransactionResponse = try await perform {
                try await self.network.request(TransactionAPI.filtered(first))
            }
            let items = response.transactions.map { $0.toItem() }
            transactions = items
            balance = response.balance
            settledBalance = response.settledBalance
            pageOffset = items.count
            totalRecords = response.metadata?.totalRecords
            hasMorePages = paginated
                ? remainingPages(loaded: items.count, pageCount: items.count, metadata: response.metadata)
                : false
            analytics.log(AnalyticsEvent.transactionListViewed, params: [
                AnalyticsParam.accountId: filter.accountId,
                AnalyticsParam.count: items.count
            ])
        } catch is CancellationError {
        } catch {
            hasMorePages = false
        }
    }

    /// Decides whether more pages remain. Prefers `metadata.totalRecords`; falls back
    /// to "the page was full" when the server omits totals.
    private func remainingPages(loaded: Int, pageCount: Int, metadata: TransactionResponse.Metadata?) -> Bool {
        if let total = metadata?.totalRecords { return loaded < total }
        return pageCount == pageSize
    }

    /// Fetches the next page and appends it. Safe to call repeatedly — it no-ops when
    /// already loading, when the first page is still loading, or when the end is reached.
    func loadNextPage() async {
        guard hasMorePages, !isLoadingMore, state != .loading,
              var next = activePageFilter else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        next.limit  = pageSize
        next.offset = pageOffset
        next.max    = pageSize

        do {
            let response: TransactionResponse = try await network.request(TransactionAPI.filtered(next))
            let items = response.transactions.map { $0.toItem() }
            transactions.append(contentsOf: items)
            balance = response.balance
            settledBalance = response.settledBalance
            pageOffset = transactions.count
            if let total = response.metadata?.totalRecords { totalRecords = total }
            // An empty page also means we've reached the end (guards against off-by-one totals).
            hasMorePages = !items.isEmpty && remainingPages(loaded: transactions.count, pageCount: items.count, metadata: response.metadata)
        } catch {
            // Keep the pages already loaded; the next scroll will retry.
        }
    }

    func loadTransactions(max: Int, accountId: Int) async {
        do {
            let response: TransactionResponse = try await perform {
                try await self.network.request(TransactionAPI.lists(max: max, accountId: accountId))
            }
            transactions = response.transactions.map { $0.toItem() }
            analytics.log(AnalyticsEvent.transactionListViewed, params: [
                AnalyticsParam.accountId: accountId,
                AnalyticsParam.count: response.transactions.count
            ])
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }

    // MARK: - Check Transfer Intent

    /// Calls `POST /transactions/check-intent` for the given phone number.
    /// Sets `checkIntentResult` on success; leaves it `nil` on error so the
    /// Pay button stays enabled (the transfer itself will fail if ineligible).
    func checkIntent(phoneNumber: String, userAction: String = "PEER-TRANSFER") async {
        checkIntentResult = nil
        do {
            let request = TransactionRequest.CheckMode(
                phoneNumber: phoneNumber,
                userAction: userAction
            )
            let response: CheckIntentResponse = try await perform {
                try await self.network.request(TransactionAPI.checkType(request))
            }
            checkIntentResult = response
        } catch is CancellationError {
            // View dismissed mid-flight — no action needed.
        } catch {
            // Error already surfaced via BaseViewModel alert.
            // checkIntentResult stays nil → Pay button remains enabled.
        }
    }

    // MARK: - Submit Internal Transfer

    /// Returns `true` on success. Errors are surfaced via BaseViewModel toast.
    @discardableResult
    func submitInternalTransfer(request: TransactionRequest.Internal) async -> Bool {
        do {
            let _: TransferInternalResponse = try await perform {
                try await self.network.request(TransactionAPI.internals(request))
            }
            analytics.log(AnalyticsEvent.internalTransferInitiated, params: [
                AnalyticsParam.amount: request.amount,
                AnalyticsParam.fromAccountId: request.fromAccountId,
                AnalyticsParam.toAccountId: request.toAccountId
            ])
            return true
        } catch is CancellationError {
            return false
        } catch {
            analytics.log(AnalyticsEvent.internalTransferFailed, params: [
                AnalyticsParam.amount: request.amount,
                AnalyticsParam.fromAccountId: request.fromAccountId,
                AnalyticsParam.toAccountId: request.toAccountId
            ])
            return false
        }
    }
}
