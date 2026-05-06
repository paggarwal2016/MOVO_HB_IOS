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
    private let preselectedFromCard: VCardListResponse?

    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedFromAccount: SavingsAccountInfo?
    @State private var selectedToCard: VCardListResponse?
    @State private var primaryCard: VCardsList?
    @State private var cardsList: [VCardListResponse] = []
    @State private var showCardSheet = false

    var onDismiss: () -> Void

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool {
        amount > 0 && selectedFromAccount != nil && selectedToCard?.savingsAccountId != nil
    }

    init(
        toClientId: Int,
        fromAccount: SavingsAccountInfo?,
        nonPrimaryAccounts: [SavingsAccountInfo],
        preselectedFromCard: VCardListResponse? = nil,
        container: AppContainer,
        onDismiss: @escaping () -> Void,
    ) {
        self.toClientId = toClientId
        self.preselectedFromCard = preselectedFromCard
        _selectedFromAccount = State(initialValue: fromAccount)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MovoBackground()
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
            .sheet(isPresented: $showCardSheet) {
                CardPickerSheet(cards: cardsList, selected: $selectedToCard)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                if preselectedFromCard == nil {
                    primaryCard = try? await vcardVM.getVCardPrimary()?.data
                }
                let all = (try? await vcardVM.getVCardsAll()) ?? []
                let excludeNumber = preselectedFromCard?.cardNumber ?? primaryCard?.cardNumber
                cardsList = all.filter { $0.cardNumber != excludeNumber }
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

    // MARK: - From Picker

    private var fromAccountPicker: some View {
        Group {
            if let card = preselectedFromCard {
                CardChipRow(
                    name: card.name ?? "Card",
                    lastFour: card.lastFour ?? "••••",
                    badge: nil,
                    showIcon: false,
                )
            } else if let card = primaryCard {
                CardChipRow(
                    name: card.name ?? "Primary Card",
                    lastFour: card.lastFour ?? "••••",
                    badge: .cardPrimary,
                    showIcon: false,
                )
            } else {
                CardChipSkeleton(card: false)
            }
        }
    }

    // MARK: - To Picker

    private var toAccountPicker: some View {
        Group {
            if cardsList.isEmpty && primaryCard == nil {
                CardChipSkeleton(card: false)
            } else if cardsList.isEmpty {
                Text("No other cards available")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showCardSheet = true
                } label: {
                    HStack {
                        if let card = selectedToCard {
                            CardChipRow(
                                name: card.name ?? "Virtual Card",
                                lastFour: card.lastFour ?? "••••",
                                badge: nil,
                                showIcon: false,
                                showChevron: true
                            )
                        } else {
                            Text("Select destination card")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
            phoneNumber: nil,
            userAction: "Internal-Transfer"
        )
        guard await transVM.submitInternalTransfer(request: request) else { return }
        ToastManager.shared.show("Money transfer successfully.", style: .success, position: .bottom)
        dismiss()
        onDismiss()
    }
}

// MARK: - Card Chip Row

private struct CardChipRow: View {
    let name: String
    let lastFour: String
    let badge: BadgeStatus?
    var showIcon: Bool = true
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if showIcon {
                Image(systemName: "creditcard")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("•••• \(lastFour)")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let badge {
                StatusBadge(status: badge, size: .small)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Card Chip Skeleton

private struct CardChipSkeleton: View {
    var card: Bool = true
    var body: some View {
        HStack(spacing: 10) {
            if card {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .shimmer()
            }
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 90, height: 11)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 9)
                    .shimmer()
            }
            Spacer()
        }
    }
}

// MARK: - Card Picker Sheet

private struct CardPickerSheet: View {
    let cards: [VCardListResponse]
    @Binding var selected: VCardListResponse?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(cards, id: \.cardNumber) { card in
                        Button {
                            selected = card
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CardChipRow(
                                    name: card.name ?? "Virtual Card",
                                    lastFour: card.lastFour ?? "••••",
                                    badge: nil
                                )
                                Image(systemName: selected?.cardNumber == card.cardNumber
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected?.cardNumber == card.cardNumber
                                                     ? Color.primary
                                                     : Color(.systemGray4))
                                    .animation(.spring(duration: 0.2), value: selected?.cardNumber)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selected?.cardNumber == card.cardNumber
                                            ? Color.primary.opacity(0.25)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
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
                .frame(width: 70, alignment: .leading)
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
