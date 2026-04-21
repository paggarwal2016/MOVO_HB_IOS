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
    private let allAccounts: [SavingsAccountInfo]

    // Editable
    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedFromAccount: SavingsAccountInfo?
    @State private var selectedToAccount: SavingsAccountInfo?
    
    var onDismiss:() -> Void
    
    private var availableToAccounts: [SavingsAccountInfo] {
        allAccounts.filter { $0.id != selectedFromAccount?.id }
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool {
        amount > 0 && selectedFromAccount != nil && selectedToAccount != nil
    }

    init(
        toClientId: Int,
        fromAccount: SavingsAccountInfo?,
        nonPrimaryAccounts: [SavingsAccountInfo],
        container: AppContainer,
        onDismiss: @escaping () -> Void,
    ) {
        self.toClientId = toClientId
        let primary = fromAccount.map { [$0] } ?? []
        self.allAccounts = primary + nonPrimaryAccounts
        _selectedFromAccount = State(initialValue: fromAccount)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        self.onDismiss = onDismiss
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
            .navigationTitle("Transfer Money")
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
                    }
                }
            }
            .overlay {
                if transVM.state == .loading {
                    SpinnerView()
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
            FieldRow(label: "From") {
                fromAccountPicker
            }
            Divider()
            FieldRow(label: "To") {
                toAccountPicker
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

    private var fromAccountPicker: some View {
        Group {
            if allAccounts.isEmpty {
                Text("No accounts")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(allAccounts) { account in
                        Button {
                            selectedFromAccount = account
                            if selectedToAccount?.id == account.id {
                                selectedToAccount = nil
                            }
                        } label: {
                            Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                        }
                    }
                } label: {
                    HStack {
                        if let account = selectedFromAccount {
                            Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .animation(.none, value: selectedFromAccount?.id)
                }
            }
        }
    }

    private var toAccountPicker: some View {
        Group {
            if availableToAccounts.isEmpty {
                Text("No accounts")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(availableToAccounts) { account in
                        Button {
                            selectedToAccount = account
                        } label: {
                            Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                        }
                    }
                } label: {
                    HStack {
                        if let account = selectedToAccount {
                            Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .animation(.none, value: selectedToAccount?.id)
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let formatted = amount.formatted(.currency(code: "USD"))
        return VStack(spacing: 0) {
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
                UIApplication.shared.dismissKeyboard()
                Task { await submitTransfer() }
            } label: {
                Text("Confirm Transfer")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(isValid ? Color.primary : Color(.systemGray5))
                    .foregroundStyle(isValid ? Color(.systemBackground) : Color(.tertiaryLabel))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValid)
        }
    }

    // MARK: - Submit

    private func submitTransfer() async {
        guard let toAccount = selectedToAccount, let from = selectedFromAccount else { return }
        let request = TransactionRequest.Internal(
            description: descriptionText,
            amount: amount,
            toAccountId: toAccount.id,
            toClientId: toClientId,
            fromAccountId: from.id,
            phoneNumber: nil
        )
        guard await transVM.submitInternalTransfer(request: request) else { return }
        ToastManager.shared.show("Money transfer successfully.", style: .success, position: .bottom)
        dismiss()
        onDismiss()
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
