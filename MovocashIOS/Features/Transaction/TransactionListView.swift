//
//  TransactionListView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/05/26.
//

import SwiftUI

// MARK: - Transaction Mode

enum TransactionMode {
    case individual  // single card — card last 4 filter hidden
    case common      // all cards  — card last 4 filter visible
}

// MARK: - TransactionListView

struct TransactionListView: View {

    @StateObject private var viewModel: TransactionViewModel

    private let accountId: Int
    private let mode: TransactionMode
    @State private var activeFilter:  TransactionFilter
    @State private var pendingFilter: TransactionFilter
    @State private var showFilterSheet = false

    init(container: AppContainer, accountId: Int, mode: TransactionMode = .common) {
        self.accountId = accountId
        self.mode = mode
        _viewModel = StateObject(wrappedValue: container.makeTransactionViewModel())
        let base = TransactionFilter(accountId: accountId)
        _activeFilter  = State(initialValue: base)
        _pendingFilter = State(initialValue: base)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppColor.app.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                transactionContent
            }

            // MARK: Floating Action Button
            Button {
                pendingFilter   = activeFilter
                showFilterSheet = true
            } label: {
                ZStack() {
                    Circle()
                        .fill(AppColor.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.gray.opacity(0.35), radius: 12, x: 0, y: 5)
                    Image("filter")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColor.app)
                    if activeFilter.hasActiveFilters {
                        Circle()
                            .fill(AppColor.primaryDisabled)
                            .frame(width: 12, height: 12)
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 28)
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { applyNavBarAppearance() }
        .sheet(isPresented: $showFilterSheet) {
            TransactionFilterView(filter: $pendingFilter, showLast4: mode == .common) {
                activeFilter = pendingFilter
                Task { await viewModel.loadTransactionsFiltered(filter: activeFilter) }
                showFilterSheet = false
            } onReset: {
                pendingFilter = TransactionFilter(accountId: accountId)
                activeFilter  = pendingFilter
                Task { await viewModel.loadTransactionsFiltered(filter: activeFilter) }
                showFilterSheet = false
            } onCancel: {
                showFilterSheet = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task { await viewModel.loadTransactionsFiltered(filter: activeFilter) }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            TextField("Search transactions...", text: $viewModel.searchText)
                .font(AppFont.activityName)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var transactionContent: some View {
        if viewModel.state == .loading && viewModel.transactions.isEmpty {
            loadingSkeleton
        } else if viewModel.groupedTransactions.isEmpty {
            emptyState
        } else {
            transactionList
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(viewModel.groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.items) { item in
                        transactionRow(item)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack {
                        Text(group.label)
                            .font(AppFont.activityName)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(AppFont.cta)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 2)
                }
            }
            Text("\(viewModel.filteredTransactions.count) transaction\(viewModel.filteredTransactions.count == 1 ? "" : "s")")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadTransactionsFiltered(filter: activeFilter) }
    }

    // MARK: - Transaction Row

    private func transactionRow(_ item: TransactionItem) -> some View {
        let isPending = item.status.lowercased() == "pending"
        let isFailed  = item.status.lowercased() == "failed"
                     || item.status.lowercased() == "declined"

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor(for: item.type).opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: iconName(for: item.type))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor(for: item.type))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(Font.montserrat(.semiBold, size: 14))
                    .foregroundStyle(isFailed ? .secondary : .primary)
                    .lineLimit(1)
                    .strikethrough(isFailed)
                HStack(spacing: 4) {
                    Text(item.subtitle)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(shortTime(item.date))
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amountFormatted)
                    .font(AppFont.activityAmount)
                    .foregroundStyle(
                        isFailed      ? Color.secondary  :
                        item.isCredit ? Color.successGreen : Color.primary
                    )
                if isPending {
                    statusBadge("Pending", color: .warningOrange)
                } else if isFailed {
                    statusBadge("Failed", color: .errorRed)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 0.5))
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label.uppercased())
            .font(AppFont.quickAction)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(AppColor.primaryText)
            VStack(spacing: 6) {
                Text(viewModel.searchText.isEmpty && !activeFilter.hasActiveFilters
                     ? "No transactions yet"
                     : "No results found")
                    .font(AppFont.hero)
                    .foregroundStyle(AppColor.primaryText)
                Text(viewModel.searchText.isEmpty && !activeFilter.hasActiveFilters
                     ? "Your transactions will appear here once activity begins."
                     : "Try adjusting your search or clearing the filters.")
                    .font(AppFont.activityName)
                    .foregroundStyle(AppColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            if activeFilter.hasActiveFilters {
                Button("Clear Filters") {
                    activeFilter  = TransactionFilter(accountId: accountId)
                    pendingFilter = activeFilter
                    Task { await viewModel.loadTransactionsFiltered(filter: activeFilter) }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(AppColor.app)
                .tint(AppColor.primary)
            }
            Spacer()
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 140, height: 13)
                        RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray6)).frame(width: 90,  height: 11)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 60, height: 13)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .allowsHitTesting(false)
    }

    // MARK: - Icon Helpers

    private func iconName(for type: TransactionType) -> String {
        switch type {
        case .deposit:  return "arrow.down.circle.fill"
        case .withdraw: return "arrow.up.circle.fill"
        case .payment:  return "creditcard.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .unknown:  return "questionmark.circle.fill"
        }
    }

    private func iconColor(for type: TransactionType) -> Color {
        switch type {
        case .deposit:  return .successGreen
        case .withdraw: return .errorRed
        case .payment:  return .softBlue
        case .transfer: return .accentPurple
        case .unknown:  return Color(.systemGray3)
        }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func applyNavBarAppearance() {
        let titleColor = UIColor(AppColor.primaryText)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
