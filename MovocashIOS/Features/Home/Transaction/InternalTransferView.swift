//
//  InternalTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import SwiftUI

// MARK: - Transfer Flow Mode

enum TransferFlowMode {
    /// Both sides interactive, swap allowed (Flow 1 — Move Money)
    case standard
    /// From is fixed, To is pickable, no swap (Flow 3 — primary card detail)
    case fixedFrom
    /// Both sides fixed, no swap (Flow 2 — secondary card detail)
    case fixedBoth(toCard: VCardListResponse)
}

struct InternalTransferView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @StateObject private var transVM: TransactionViewModel
    @StateObject private var vcardVM: VCardViewModel
    @StateObject private var achVM: PlaidAchViewModel

    private let mode: TransferFlowMode
    private let toClientId: Int
    private let preselectedFromCard: VCardListResponse?
    private let primaryLinkedCard: VCardListResponse?
    private let initialCards: [VCardListResponse]
    private let allAccounts: [SavingsAccountInfo]

    @State private var amountText = "0"
    @State private var descriptionText = ""
    @State private var selectedFromAccount: SavingsAccountInfo?
    @State private var selectedFromCard: VCardListResponse?
    @State private var selectedToCard: VCardListResponse?
    @State private var isSwapped = false
    @State private var showCardSheet = false
    @State private var showFromCardSheet = false
    @State private var showConfirmSheet = false
    @State private var submitTask: Task<Void, Never>?

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

    // Cards available to select as "to" destination (excludes current from-card)
    private var toCardsList: [VCardListResponse] {
        allCards.filter { card in
            guard card.savingsAccountId != nil else { return false }
            return card.id != selectedFromCard?.id
        }
    }

    // Cards available to select as "from" source (excludes current to-card)
    private var fromCardsList: [VCardListResponse] {
        allCards.filter { card in
            guard card.savingsAccountId != nil else { return false }
            return card.id != selectedToCard?.id
        }
    }

    @FocusState private var isAmountFocused: Bool

    var onDismiss: () -> Void

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool {
        amount > 0
            && selectedFromCard?.savingsAccountId != nil
            && selectedToCard?.savingsAccountId != nil
    }

    init(
        mode: TransferFlowMode = .standard,
        toClientId: Int,
        fromAccount: SavingsAccountInfo?,
        nonPrimaryAccounts: [SavingsAccountInfo],
        preselectedFromCard: VCardListResponse? = nil,
        primaryLinkedCard: VCardListResponse? = nil,
        initialCards: [VCardListResponse] = [],
        container: AppContainer,
        onDismiss: @escaping () -> Void,
    ) {
        self.mode = mode
        self.toClientId = toClientId
        self.preselectedFromCard = preselectedFromCard
        self.primaryLinkedCard = primaryLinkedCard
        self.initialCards = initialCards
        var accounts = nonPrimaryAccounts
        if let from = fromAccount { accounts.insert(from, at: 0) }
        self.allAccounts = accounts
        _selectedFromAccount = State(initialValue: fromAccount)
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        self.onDismiss = onDismiss
        let fixedToCard: VCardListResponse?
        if case .fixedBoth(let toCard) = mode { fixedToCard = toCard } else { fixedToCard = nil }
        let firstDestination = initialCards.first(where: { $0.savingsAccountId != nil && $0.id != preselectedFromCard?.id })
        _selectedFromCard = State(initialValue: preselectedFromCard)
        _selectedToCard = State(initialValue: fixedToCard ?? firstDestination)
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
            if transVM.state == .loading || achVM.state == .loading {
                Color.black.opacity(0.5).ignoresSafeArea()
                SpinnerView()
            }
        }
        .background(Color.movo.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: isAmountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        .onChange(of: selectedFromCard?.id) { _ in
            guard let accountId = selectedFromCard?.savingsAccountId else { return }
            selectedFromAccount = allAccounts.first { $0.id == accountId }
        }
        // To-card picker (bottom slot / top slot when swapped back)
        .sheet(isPresented: $showCardSheet) {
            let rowHeight: CGFloat = 86
            let fixedHeight = CGFloat(toCardsList.count) * rowHeight + 80
            CardPickerSheet(cards: toCardsList, selected: $selectedToCard)
                .presentationDetents(toCardsList.count > 5 ? [.medium, .large] : [.height(fixedHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
        }
        // From-card picker (top slot when swapped)
        .sheet(isPresented: $showFromCardSheet) {
            let rowHeight: CGFloat = 86
            let fixedHeight = CGFloat(fromCardsList.count) * rowHeight + 80
            CardPickerSheet(cards: fromCardsList, selected: $selectedFromCard)
                .presentationDetents(fromCardsList.count > 5 ? [.medium, .large] : [.height(fixedHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
            
            
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .internalTransfer,
                amount: amountText,
                fromName: selectedFromCard?.savingsAccountNickname ?? selectedFromCard?.name ?? "Card",
                fromMask: selectedFromCard?.maskedNumber,
                toName: selectedToCard?.savingsAccountNickname ?? selectedToCard?.name ?? "Virtual Card",
                toMask: selectedToCard?.maskedNumber,
                note: descriptionText.isEmpty ? nil : descriptionText,
                isLoading: transVM.state == .loading,
                onCancel: { showConfirmSheet = false },
                onConfirm: {
                    showConfirmSheet = false
                    submitTask = Task { await submitTransfer() }
                }
            )
            .padding(.top, 30)
            .presentationDetents([.height(descriptionText.isEmpty ? 420 : 490)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
        }
        .fullScreenCover(item: $achVM.peerTransferSuccess) { data in
            SuccessConfirmationView(
                viewModel: SuccessConfirmationViewModel(success: data) {
                    achVM.peerTransferSuccess = nil
                    dismiss()
                    onDismiss()
                }
            )
        }
        .task {
            if case .fixedBoth = mode { return }
            if initialCards.isEmpty {
                await vcardVM.loadCards()
            }
            resolveCardSelection()
        }
        .onChange(of: vcardVM.hasLoadedCards) { loaded in
            guard loaded else { return }
            resolveCardSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            submitTask?.cancel()
            submitTask = nil
            showConfirmSheet = false
            showCardSheet = false
            showFromCardSheet = false
            (securedDismiss ?? dismiss)()
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
            CircularNavButton(systemName: "xmark") { (securedDismiss ?? dismiss)() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .textStyle(Typography.amountPrefix)
                    .foregroundColor(Color.movo.textSecondary)
                    .baselineOffset(25)

                let parts = amountText.split(separator: ".")
                Text(parts.first.map(String.init) ?? "0")
                    .textStyle(Typography.amountInput)
                    .monospacedDigit()
                    .foregroundColor(Color.movo.textPrimary)

                Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                    .textStyle(Typography.amountPrefix)
                    .monospacedDigit()
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
            slotLabel("FROM")
            fromSlot
            swapDivider
            slotLabel("TO")
            toSlot
        }
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                )
        )
    }

    private func slotLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.eyebrow)
            .foregroundColor(Color.movo.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xs)
    }

    @ViewBuilder
    private var fromSlot: some View {
        if case .standard = mode {
            if isSwapped {
                pickableSlot(
                    card: selectedFromCard,
                    balance: selectedFromAccount?.formattedBalance ?? "",
                    showChevron: !fromCardsList.isEmpty,
                    onTap: { showFromCardSheet = true }
                )
            } else {
                fixedSlot(
                    card: selectedFromCard,
                    balance: selectedFromAccount?.formattedBalance ?? "",
                    nickname: selectedFromAccount?.nickname
                )
            }
        } else {
            fixedSlot(
                card: selectedFromCard,
                balance: selectedFromAccount?.formattedBalance ?? "",
                nickname: selectedFromAccount?.nickname
            )
        }
    }

    @ViewBuilder
    private var swapDivider: some View {
        let showSwap: Bool = {
            if case .standard = mode { return true }
            if case .fixedBoth = mode { return true }
            return false
        }()

        if showSwap {
            ZStack {
                Rectangle()
                    .fill(Color.movo.cardBorder)
                    .frame(height: Stroke.hairline)
                    .padding(.horizontal, Spacing.lg)
                    .allowsHitTesting(false)
                Button { swapAccounts() } label: {
                    Circle()
                        .fill(Color.movo.elevated)
                        .overlay(Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.movo.accent)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
            .padding(.vertical, Spacing.md)
        } else {
            Rectangle()
                .fill(Color.movo.cardBorder)
                .frame(height: Stroke.hairline)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
        }
    }

    @ViewBuilder
    private var toSlot: some View {
        if case .fixedBoth = mode {
            fixedSlot(
                card: selectedToCard,
                balance: toCardAccount?.formattedBalance ?? "",
                nickname: toCardAccount?.nickname
            )
        } else if case .standard = mode {
            if isSwapped {
                fixedSlot(
                    card: selectedToCard,
                    balance: toCardAccount?.formattedBalance ?? "",
                    nickname: toCardAccount?.nickname
                )
            } else {
                pickableToContent
            }
        } else {
            // fixedFrom: To is always pickable
            pickableToContent
        }
    }

    @ViewBuilder
    private var pickableToContent: some View {
        if isLoadingCards {
            cardLoadingRow
        } else {
            Button { showCardSheet = true } label: {
                pickableRowContent(
                    card: selectedToCard,
                    balance: toCardAccount?.formattedBalance ?? "",
                    showChevron: !toCardsList.isEmpty
                )
            }
            .buttonStyle(.plain)
            .disabled(toCardsList.isEmpty)
        }
    }

    // MARK: - Row Helpers

    // Fixed row: no chevron, not tappable (primary card design)
    private func fixedSlot(card: VCardListResponse?, balance: String, nickname: String? = nil) -> some View {
        let displayName = card?.savingsAccountNickname ?? card?.name ?? "Card"
        let isPrimary = card != nil && card?.id == primaryLinkedCard?.id
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevatedHigh)
                MovoMVSymbol().frame(width: 28, height: 28)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                    if isPrimary {
                        StatusPill("PRIMARY", variant: .accent)
                    }
                }
                Text(card?.maskedNumber ?? "•••• •••• •••• ••••")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
                Text(card?.displayBalance ?? balance)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // Pickable slot: chevron + tappable (secondary card design)
    @ViewBuilder
    private func pickableSlot(
        card: VCardListResponse?,
        balance: String,
        showChevron: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        if isLoadingCards {
            cardLoadingRow
        } else {
            Button { onTap() } label: {
                pickableRowContent(card: card, balance: balance, showChevron: showChevron)
            }
            .buttonStyle(.plain)
        }
    }

    private func pickableRowContent(card: VCardListResponse?, balance: String, showChevron: Bool) -> some View {
        let cardName = card?.savingsAccountNickname ?? card?.name ?? "Select destination card"
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevatedHigh)
                if card != nil {
                    MovoMVSymbol().frame(width: 28, height: 28)
                } else {
                    Image(systemName: "creditcard")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.movo.textDisabled)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(cardName)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(card != nil ? Color.movo.textPrimary : Color.movo.textDisabled)
                if let card {
                    Text(card.maskedNumber)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                    Text(card.displayBalance)
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

    private var cardLoadingRow: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color.movo.elevatedHigh)
                .frame(width: 52, height: 52)
            ProgressView().tint(Color.movo.textSecondary)
            Text("Loading cards…")
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textTertiary)
            Spacer()
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
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
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
                    .textStyle(Typography.buttonLarge)
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

    // MARK: - Card Selection

    private func resolveCardSelection() {
        if selectedFromCard == nil {
            selectedFromCard = allCards.first { $0.savingsAccountId == selectedFromAccount?.id }
                ?? allCards.first { $0.savingsAccountId != nil && $0.id != selectedToCard?.id }
        }
        if case .fixedBoth = mode { return }
        if selectedToCard == nil {
            selectedToCard = toCardsList.first
        }
    }

    // MARK: - Swap

    private func swapAccounts() {
        guard let oldFrom = selectedFromCard, let oldTo = selectedToCard else { return }
        selectedFromCard = oldTo
        selectedToCard = oldFrom
        selectedFromAccount = allAccounts.first { $0.id == oldTo.savingsAccountId }
        isSwapped.toggle()
    }

    // MARK: - Submit

    private func submitTransfer() async {
        guard let fromCard = selectedFromCard else { return }
        guard !Task.isCancelled else { return }

        await achVM.sendMoneyToContact(
            fromCard: fromCard,
            toName: selectedToCard?.savingsAccountNickname ?? selectedToCard?.name ?? "",
            normalizedPhone: "",
            amount: amount,
            amountText: amountText,
            description: descriptionText.isEmpty ? nil : descriptionText,
            isInternal: true,
            toClientId: toClientId,
            toAccountId: selectedToCard?.savingsAccountId
        )
        let success = await transVM.submitInternalTransfer(request: request)

        // If the task was cancelled mid-flight (session expired), do nothing —
        // the .onReceive handler already dismissed this view.
        guard !Task.isCancelled else { return }
        guard success else { return }

        ToastManager.shared.show("Money transfer successfully.", style: .success, position: .bottom)
        (securedDismiss ?? dismiss)()
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
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                Text("•••• •••• •••• \(lastFour)")
                    .textStyle(Typography.mono)
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
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss

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
                                    MovoMVSymbol().frame(width: 26, height: 26)
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(card.savingsAccountNickname ?? card.name ?? "Virtual Card")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.movo.textPrimary)
                                    Text(card.maskedNumber)
                                        .textStyle(Typography.subtitle)
                                        .foregroundColor(Color.movo.textTertiary)
                                    Text(card.displayBalance)
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
                            .background(Color.movo.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .strokeBorder(
                                        isSelected ? Color.movo.accentBorder : Color.movo.borderStrong,
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
            .navigationTitle("Select Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { (securedDismiss ?? dismiss)() }
                        .textStyle(Typography.buttonLarge)
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
            .background(Color.movo.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
            )
    }
}
