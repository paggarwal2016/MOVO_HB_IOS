//
//  SavingAccountDetailView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 16/03/26.
//

import SwiftUI

// MARK: - SavingAccountDetailView

struct SavingAccountDetailView: View {

    let accountId: Int
    private let container: AppContainer

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @StateObject private var transVM: TransactionViewModel
    @State private var showAll = false

    init(accountId: Int, showAccountCard: Bool = true, container: AppContainer) {
        self.accountId = accountId
        self.container = container
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if transVM.state == .loading {
                    skeletonContent
                } else if transVM.transactions.isEmpty {
                    EmptyStateView(
                        image: "list.bullet.rectangle.portrait",
                        title: "No Activity",
                        description: "Activity history is not available."
                    )
                    .background(Color.movo.background.ignoresSafeArea())
                } else {
                    transactionList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { (securedDismiss ?? dismiss)() }
                        .foregroundStyle(Color.movo.accent)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAll) {
                TransactionListView(
                    container: container,
                    accountId: accountId,
                    mode: .individual,
                    initialMax: 50
                )
            }
        }
        .task { await loadDetail() }
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    TransactionRowSkeleton()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color.movo.background)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if transVM.transactions.count >= 10 {
                    HStack {
                        Spacer()
                        Button("See all") { showAll = true }
                            .font(Typography.captionSmall.font)
                            .foregroundColor(Color.movo.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 8) {
                    ForEach(transVM.transactions) { item in
                        TransactionRow(item: item)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.vertical, 10)
        }
        .background(Color.movo.background)
    }

    // MARK: - Load

    private func loadDetail() async {
        await transVM.loadTransactions(max: 10, accountId: accountId)
    }
}


// MARK: - TransactionRow

struct TransactionRow: View {
    let item: TransactionItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.isCredit ? Color.movo.successTint : Color.movo.dangerTint)
                    .frame(width: 48, height: 48)
                Image(systemName: item.isCredit ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.isCredit ? Color.movo.success : Color.movo.danger)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.movo.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.movo.textSecondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.movo.textSecondary)
                    Text(Self.dateFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundStyle(Color.movo.textSecondary)
                }
            }

            Spacer()

            Text(item.amountFormatted)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(item.isCredit ? Color.movo.success : Color.movo.danger)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.movo.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
