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
    private let initialCards: [VCardListResponse]
    private let allAccounts: [SavingsAccountInfo]

    @State private var amountText = "0"
    @State private var descriptionText = ""
    @State private var selectedFromAccount: SavingsAccountInfo?
    @State private var selectedToCard: VCardListResponse?
    @State private var showCardSheet = false
    @State private var showConfirmSheet = false

    private var toCardAccount: SavingsAccountInfo? {
        guard let id = selectedToCard?.savingsAccountId else { return nil }
        return allAccounts.first { $0.id == id }
    }

    private var isLoadingCards: Bool {
        initialCards.isEmpty && !vcardVM.hasLoadedCards
    }

    private var allCards: [VCardListResponse] {
        vcardVM.hasLoadedCards ? vcardVM.apiCards : initialCards
    }

    private var primaryCard: VCardListResponse? {
        guard preselectedFromCard == nil else { return nil }
        let fromId = selectedFromAccount?.id
        return allCards.first { $0.savingsAccountId == fromId }
    }

    private var cardsList: [VCardListResponse] {
        let fromCardId = preselectedFromCard?.id ?? primaryCard?.id
        return allCards.filter { card in
            guard card.savingsAccountId != nil else { return false }
            return card.id != fromCardId
        }
    }
    @FocusState private var isAmountFocused: Bool

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
        initialCards: [VCardListResponse] = [],
        container: AppContainer,
        onDismiss: @escaping () -> Void,
    ) {
        self.toClientId = toClientId
        self.preselectedFromCard = preselectedFromCard
        self.initialCards = initialCards
        var accounts = nonPrimaryAccounts
        if let from = fromAccount { accounts.insert(from, at: 0) }
        self.allAccounts = accounts
        _selectedFromAccount = State(initialValue: fromAccount)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        self.onDismiss = onDismiss
        let fromCardId = preselectedFromCard?.id ?? initialCards.first(where: { $0.savingsAccountId == fromAccount?.id })?.id
        let firstDestination = initialCards.first(where: { $0.savingsAccountId != nil && $0.id != fromCardId })
        _selectedToCard = State(initialValue: firstDestination)
    }

    var body: some View {
        ZStack {
            MovoBackground()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        navBar
                        amountCard
                            .padding(.horizontal, Spacing.lg)
                        transferPanel
                            .padding(.horizontal, Spacing.lg)
                        noteCard
                            .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(TapGesture().onEnded { isAmountFocused = false })

                confirmButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
            }
            if transVM.state == .loading {
                Color.black.opacity(0.5).ignoresSafeArea()
                SpinnerView()
            }
        }
        .background(Color.movo.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onChange(of: isAmountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        .sheet(isPresented: $showCardSheet) {
            CardPickerSheet(cards: cardsList, selected: $selectedToCard)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .internalTransfer,
                amount: amountText,
                fromName: preselectedFromCard?.name ?? primaryCard?.name ?? "Card",
                fromMask: (preselectedFromCard?.lastFour ?? primaryCard?.lastFour).map { "•••• \($0)" },
                toName: selectedToCard?.name ?? "Virtual Card",
                toMask: selectedToCard?.lastFour.map { "•••• \($0)" },
                note: descriptionText.isEmpty ? nil : descriptionText,
                isLoading: transVM.state == .loading,
                onCancel: { showConfirmSheet = false },
                onConfirm: {
                    showConfirmSheet = false
                    Task { await submitTransfer() }
                }
            )
            .padding(.top, 30)
            .presentationDetents([.height(descriptionText.isEmpty ? 420 : 490)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .task {
            if initialCards.isEmpty {
                await vcardVM.loadCards()
            }
            if selectedToCard == nil {
                selectedToCard = cardsList.first
            }
        }
        .onChange(of: vcardVM.hasLoadedCards) { loaded in
            guard loaded, selectedToCard == nil else { return }
            selectedToCard = cardsList.first
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Color.clear.frame(width: 32, height: 32)
            Spacer()
            Text("Transfer Money")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            CircularNavButton(systemName: "xmark") { dismiss() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }
    
    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color.movo.textSecondary)
                    .baselineOffset(25)

                let parts = amountText.split(separator: ".")
                Text(parts.first.map(String.init) ?? "0")
                    .font(.system(size: 72, weight: .bold).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary)

                Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                    .font(.system(size: 32, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color.movo.textSecondary)
                    .baselineOffset(25)
            }
            .contentShape(Rectangle())
            .onTapGesture { isAmountFocused = true }
            .overlay(
                TextField("", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .opacity(0)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Transfer Panel

    private var transferPanel: some View {
        VStack(spacing: 0) {
            fromAccountRow

            ZStack {
                Rectangle()
                    .fill(Color.movo.border)
                    .frame(height: Stroke.hairline)
                    .padding(.horizontal, Spacing.lg)
                Circle()
                    .fill(Color.movo.elevated)
                    .overlay(Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.movo.accent)
                    )
            }
            .padding(.vertical, Spacing.md)

            toAccountRow
        }
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }

    private var fromAccountRow: some View {
        let name = preselectedFromCard?.name ?? primaryCard?.name ?? "Card"
        let lastFour = preselectedFromCard?.lastFour ?? primaryCard?.lastFour ?? "••••"
        let balance = selectedFromAccount?.formattedBalance ?? ""
        let subtitle = balance.isEmpty ? "•••• \(lastFour)" : "\(balance) · •••• \(lastFour)"
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevatedHigh)
                MLogo().frame(width: 28, height: 28)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var toAccountRow: some View {
        Group {
            if isLoadingCards {
                HStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .fill(Color.movo.elevatedHigh)
                        .frame(width: 52, height: 52)
                    ProgressView().tint(Color.movo.textSecondary)
                    Text("Loading cards…")
                        .font(.system(size: 13))
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            } else {
                Button { showCardSheet = true } label: {
                    toAccountRowContent(showChevron: !cardsList.isEmpty)
                }
                .buttonStyle(.plain)
                .disabled(cardsList.isEmpty)
            }
        }
    }

    private func toAccountRowContent(showChevron: Bool) -> some View {
        let cardName = selectedToCard?.name ?? "Select destination card"
        let lastFour = selectedToCard?.lastFour ?? "••••"
        let balance = toCardAccount?.formattedBalance ?? ""
        let subtitle = balance.isEmpty ? "•••• \(lastFour)" : "\(balance) · •••• \(lastFour)"
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevatedHigh)
                if selectedToCard != nil {
                    MLogo().frame(width: 28, height: 28)
                } else {
                    Image(systemName: "creditcard")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.movo.textDisabled)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(cardName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedToCard != nil ? Color.movo.textPrimary : Color.movo.textDisabled)
                if selectedToCard != nil {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.movo.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Note Card

    private var noteCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "bubble.left")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.movo.textDisabled)

            TextField("", text: $descriptionText,
                      prompt: Text("What's it for? (optional)")
                          .foregroundColor(Color.movo.textDisabled))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.movo.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.movo.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline)
                )
        )
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            UIApplication.shared.dismissKeyboard()
            isAmountFocused = false
            showConfirmSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                Text(amount > 0 ? "Transfer $\(String(format: "%.2f", amount))" : "Transfer")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isValid ? Color.movo.onAccent : Color.movo.textDisabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule().fill(isValid ? Color.movo.accent : Color.movo.elevated)
            )
        }
        .disabled(!isValid)
        .buttonStyle(.plain)
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
            userAction: "Internal-Transfer",
            nickname: ""
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
        HStack(spacing: Spacing.sm) {
            if showIcon {
                Image(systemName: "creditcard")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.movo.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.movo.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Typography.bodyCompact.font)
                    .foregroundColor(Color.movo.textPrimary)
                Text("•••• \(lastFour)")
                    .font(Typography.mono.font)
                    .foregroundColor(Color.movo.textTertiary)
            }
            Spacer()
            if let badge {
                StatusBadge(status: badge, size: .small)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.movo.textDisabled)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Card Chip Skeleton

private struct CardChipSkeleton: View {
    var card: Bool = true
    var body: some View {
        HStack(spacing: Spacing.sm) {
            if card {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.elevated)
                    .frame(width: 36, height: 36)
                    .shimmer()
            }
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(Color.movo.elevated)
                    .frame(width: 90, height: 11)
                    .shimmer()
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(Color.movo.elevated)
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    ForEach(cards) { card in
                        let isSelected = selected?.id == card.id
                        Button {
                            selected = card
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Radius.button)
                                        .fill(Color.movo.elevatedHigh)
                                    MLogo().frame(width: 26, height: 26)
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(card.name ?? "Virtual Card")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.movo.textPrimary)
                                    Text("•••• \(card.lastFour ?? "••••")")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.movo.textTertiary)
                                }

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(isSelected ? Color.movo.accent : Color.movo.textDisabled)
                                    .animation(.spring(duration: 0.2), value: isSelected)
                            }
                            .padding(Spacing.md)
                            .background(Color.movo.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .strokeBorder(
                                        isSelected ? Color.movo.accentBorder : Color.movo.border,
                                        lineWidth: Stroke.hairline
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.movo.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Select Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Typography.buttonLarge.font)
                        .foregroundColor(Color.movo.accent)
                }
            }
        }
    }
}

// MARK: - Card Modifier

private extension View {
    func movoCard() -> some View {
        self
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
    }
}
