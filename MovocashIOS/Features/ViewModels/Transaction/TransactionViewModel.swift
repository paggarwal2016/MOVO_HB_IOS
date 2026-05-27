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

    func loadTransactionsFiltered(filter: TransactionFilter) async {
        do {
            let response: TransactionResponse = try await perform {
                try await self.network.request(TransactionAPI.filtered(filter))
            }
            transactions = response.transactions.map { $0.toItem() }
            analytics.log(AnalyticsEvent.transactionListViewed, params: [
                AnalyticsParam.accountId: filter.accountId,
                AnalyticsParam.count: response.transactions.count
            ])
        } catch is CancellationError {
        } catch {
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
    func checkIntent(phoneNumber: String) async {
        checkIntentResult = nil
        do {
            let request = TransactionRequest.CheckMode(
                phoneNumber: phoneNumber,
                userAction: "PEER-TRANSFER"
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
