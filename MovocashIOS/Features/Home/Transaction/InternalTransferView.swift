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
    @StateObject private var vcardVM: VCardViewModel

    private let toClientId: Int

    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedFromAccount: SavingsAccountInfo?
    @State private var selectedToCard: VCardListResponse?
    @State private var primaryCard: VCardsList?
    @State private var cardsList: [VCardListResponse] = []

    var onDismiss: () -> Void

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool {
        amount > 0 && selectedFromAccount != nil && selectedToCard?.savingsAccountId != nil
    }

    init(
        toClientId: Int,
        fromAccount: SavingsAccountInfo?,
        nonPrimaryAccounts: [SavingsAccountInfo],
        container: AppContainer,
        onDismiss: @escaping () -> Void,
    ) {
        self.toClientId = toClientId
        _selectedFromAccount = State(initialValue: fromAccount)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
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
            .task {
                async let primary = vcardVM.getVCardPrimary()
                async let all = vcardVM.getVCardsAll()
                primaryCard = try? await primary?.data?.first
                cardsList = (try? await all) ?? []
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
        HStack {
            if let card = primaryCard {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(card.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("•••• \(card.lastFour)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var toAccountPicker: some View {
        Group {
            if cardsList.isEmpty {
                Text("No cards available")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(cardsList, id: \.cardNumber) { card in
                        Button {
                            selectedToCard = card
                        } label: {
                            Text("\(card.name ?? "")  •••• \(card.lastFour ?? "")")
                        }
                    }
                } label: {
                    HStack {
                        if let card = selectedToCard {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name ?? "")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text("•••• \(card.lastFour ?? "")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Select card")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .animation(.none, value: selectedToCard?.cardNumber)
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
        guard let from = selectedFromAccount,
              let toCard = selectedToCard,
              let toAccountId = toCard.savingsAccountId else { return }
        let request = TransactionRequest.Internal(
            description: descriptionText,
            amount: amount,
            toAccountId: toAccountId,
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
