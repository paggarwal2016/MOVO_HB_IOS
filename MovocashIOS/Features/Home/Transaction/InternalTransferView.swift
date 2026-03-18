//
//  InternalTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import SwiftUI

struct InternalTransferView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var transVM: TransactionViewModel

    // Pre-loaded from DashboardView
    private let toClientId: Int
    private let fromAccount: SavingsAccountDetailsResponse?
    private let nonPrimaryAccounts: [SavingsAccountDetailsResponse]

    // Editable
    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedToAccount: SavingsAccountDetailsResponse?

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool {
        amount > 0 && selectedToAccount != nil && fromAccount != nil && !descriptionText.isEmpty
    }

    init(
        toClientId: Int,
        fromAccount: SavingsAccountDetailsResponse?,
        nonPrimaryAccounts: [SavingsAccountDetailsResponse],
        transVM: TransactionViewModel = AppContainer.shared.makeTransactionViewModel()
    ) {
        self.toClientId = toClientId
        self.fromAccount = fromAccount
        self.nonPrimaryAccounts = nonPrimaryAccounts
        _transVM = StateObject(wrappedValue: transVM)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        amountCard
                        fieldsCard
                        summaryCard
                        confirmButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Internal transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: 10) {
            Text("TRANSFER AMOUNT")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                TextField("0", text: $amountText)
                    .font(.system(size: 48, weight: .light))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .card()
    }

    // MARK: - Fields Card

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            FieldRow(label: "From account") {
                Text(fromAccount?.accountNumber ?? "—")
                    .font(.system(size: 14, weight: .medium))
            }
            Divider()
            FieldRow(label: "To account") {
                toAccountPicker
            }
            Divider()
            FieldRow(label: "Client ID") {
                Text("\(toClientId)")
                    .font(.system(size: 14, weight: .medium))
            }
            Divider()
            FieldRow(label: "Description") {
                TextField("Enter description", text: $descriptionText)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .card()
    }

    private var toAccountPicker: some View {
        Group {
            if nonPrimaryAccounts.isEmpty {
                Text("No accounts")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(nonPrimaryAccounts) { account in
                        Button {
                            selectedToAccount = account
                        } label: {
                            VStack(alignment: .leading) {
                                Text(account.nickname ?? account.clientName)
                                Text(account.maskedAccountNumber)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let account = selectedToAccount {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(account.nickname ?? account.clientName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(account.maskedAccountNumber)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Select account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let formatted = amount.formatted(.currency(code: "USD"))
        return VStack(spacing: 0) {
            SummaryRow(label: "Transfer amount", value: formatted)
            SummaryRow(label: "Fee", value: "$0.00")
            Divider().padding(.vertical, 8)
            SummaryRow(label: "Total deducted", value: formatted, bold: true)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await submitTransfer() }
            } label: {
                Text("Confirm transfer")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(isValid ? Color.primary : Color(.systemGray5))
                    .foregroundStyle(isValid ? Color(.systemBackground) : Color(.tertiaryLabel))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValid)
            Text("Transfers are usually instant")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Submit

    private func submitTransfer() async {
        guard let toAccount = selectedToAccount, let from = fromAccount else { return }
        let request = TransactionRequest.Internal(
            description: descriptionText,
            amount: amount,
            toAccountId: toAccount.id,
            toClientId: toClientId,
            fromAccountId: from.id
        )
        do {
            _ = try await transVM.postInternal(request: request)
            dismiss()
        } catch {
            // Handled by BaseViewModel / ToastManager
        }
    }
}

// MARK: - Shared Field Row

private struct FieldRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
            trailing()
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: bold ? 13 : 12, weight: bold ? .medium : .regular))
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: bold ? 13 : 12, weight: .medium))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Card Modifier

private extension View {
    func card() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.separator), lineWidth: 0.5))
    }
}
