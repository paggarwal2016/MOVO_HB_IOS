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

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var savingVM: SavingsAccountViewModel

    init(
        accountId: Int,
        savingVM: SavingsAccountViewModel = AppContainer.shared.makeSavingsAccountViewModel()
    ) {
        self.accountId = accountId
        _savingVM = StateObject(wrappedValue: savingVM)
    }

    @State private var detail: SavingsAccountDetailsResponse?
    @State private var transactions: [TransactionItem] = []
    @State private var copiedField: String?

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if let detail {
                        detailContent(detail)
                    } else {
                        Color(.systemGroupedBackground).ignoresSafeArea()
                    }
                }
                .navigationTitle(detail?.nickname ?? "Account Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(AppColors.primary)
                            .fontWeight(.semibold)
                    }
                }
            }

            if savingVM.state == .loading {
                SpinnerView()
            }
        }
        .task { await loadDetail() }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ detail: SavingsAccountDetailsResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                accountCard(detail)
                transactionSection
            }
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Account Card

    private func accountCard(_ detail: SavingsAccountDetailsResponse) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 180)

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: -30, y: 30)

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 100, height: 100)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 20, y: -20)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(detail.clientName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))

                    if detail.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(detail.status.displayTitle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.35))
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("AVAILABLE BALANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.2)
                    Text(detail.formattedBalance)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACCOUNT NO.")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.0)
                        Text(detail.accountNumber)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ACCOUNT BALANCE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.0)
                        Text(detail.formattedAccountBalance)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Transaction Section

    private var transactionSection: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack {
                Text("Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(transactions.isEmpty ? TransactionItem.dummy.count : transactions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            // MARK: List
            let items = transactions.isEmpty ? TransactionItem.dummy : transactions

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        TransactionRow(item: item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 10)
    }

    // MARK: - Load

    private func loadDetail() async {
        do {
            detail = try await savingVM.getSavingAccountDetails(accountID: accountId)
        } catch {
            ToastManager.shared.show("Failed to load account details.", style: .error, position: .bottom)
        }
    }
}


// MARK: - TransactionRow

struct TransactionRow: View {
    let item: TransactionItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.isCredit ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: item.isCredit ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.isCredit ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.amountFormatted)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.isCredit ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
