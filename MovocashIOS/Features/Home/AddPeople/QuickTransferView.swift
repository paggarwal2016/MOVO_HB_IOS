//
//  QuickTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI
import MobileBankingSDK

struct QuickTransferView: View {

    let contact: ContactRecord
    let cards: [VCardListResponse]
    let primaryLinkedCard: VCardListResponse?
    /// Recipient enrollment result from a check-intent already run by the caller
    /// (the Pay Anyone confirmation popup). Drives the transfer route. `nil` when the
    /// caller didn't pre-resolve it.
    let recipientExists: Bool?

    private var accountBalance: Decimal {
        Decimal(primaryLinkedCard?.savingsAccountAvailableBalance ?? 0)
    }

    private var primaryAccountNickname: String? {
        primaryLinkedCard?.savingsAccountNickname ?? primaryLinkedCard?.name
    }

    // Primary card prepended so it is the first option in the selection sheet.
    private var displayCards: [VCardListResponse] {
        guard let primary = primaryLinkedCard else { return cards }
        return [primary] + cards
    }

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @StateObject private var transVM: TransactionViewModel
    @StateObject private var achVM: PlaidAchViewModel
    @FocusState private var amountFocused: Bool

    @State private var amountText = "0"
    @State private var descriptionText = ""
    @State private var selectedCard: VCardListResponse?
    @State private var showConfirmSheet = false
    @State private var showAccountSheet = false
    @State private var sendTask: Task<Void, Never>?

    var onSuccess: () -> Void = {}

    init(contact: ContactRecord, container: AppContainer, cards: [VCardListResponse], primaryLinkedCard: VCardListResponse? = nil, recipientExists: Bool? = nil, onSuccess: @escaping () -> Void = {}) {
        self.contact = contact
        self.cards = cards
        self.primaryLinkedCard = primaryLinkedCard
        self.recipientExists = recipientExists
        self.onSuccess = onSuccess
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _selectedCard = State(wrappedValue: primaryLinkedCard ?? cards.first)
    }

    private var amount: Double { Double(amountText) ?? 0 }

    /// Pay button is enabled only when:
    ///  • amount > 0 and a card is selected
    ///  • the check-intent result confirms the recipient exists (`exists == true`)
    ///    or the result is still pending (`nil` while loading / on API error)
    private var isValid: Bool { amount > 0 && selectedCard != nil }

    // MARK: - Amount display helpers

    private var availableBalanceDisplay: String {
        "$\(accountBalance.toCurrencyString())"
    }

    private var availableBalanceDouble: Double {
        NSDecimalNumber(decimal: accountBalance).doubleValue
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            MovoBackground()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        navBar
                        recipientSection
                        AmountEntrySection(
                            amountText: $amountText,
                            amountFocused: $amountFocused,
                            availableText: "\(availableBalanceDisplay) available",
                            maxValue: availableBalanceDouble
                        )
                        NoteCard(text: $descriptionText)
                        accountCard
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }
                .onTapGesture { amountFocused = false }
                .scrollDismissesKeyboard(.immediately)

                sendButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
            }
            .blur(radius: showAccountSheet ? 3 : 0)

            if transVM.state == .loading || achVM.state == .loading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                SpinnerView()
            }
        }
        .background(Color.movo.background)
        .navigationBarHidden(true)
        .onChange(of: amountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        .globalAlert()
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            sendTask?.cancel()
            sendTask = nil
            showConfirmSheet = false
            showAccountSheet = false
            (securedDismiss ?? dismiss)()
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .peer,
                amount: amountText,
                fromName: {
                    guard let card = selectedCard else { return "—" }
                    let isPrimary = card.id == primaryLinkedCard?.id
                    if isPrimary, let nick = primaryAccountNickname, !nick.isEmpty { return nick }
                    return card.displayName
                }(),
                fromMask: selectedCard?.maskedNumber,
                toName: contact.nickname ?? contact.phoneNumber ?? "—",
                toMask: contact.phoneNumber.map { "••\($0.suffix(4))" },
                note: descriptionText.isEmpty ? nil : descriptionText,
                isLoading: false,
                onCancel: { showConfirmSheet = false },
                onConfirm: {
                    showConfirmSheet = false
                    sendTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        await sendMoney()
                    }
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
                    onSuccess()
                    (securedDismiss ?? dismiss)()
                }
            )
        }
        .sheet(isPresented: $showAccountSheet) {
            accountSelectionSheet
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button(action: { (securedDismiss ?? dismiss)() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.movo.elevated, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Pay")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: - Recipient

    private var recipientSection: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(Color.movo.elevated)
                Circle().strokeBorder(Color.movo.accent, lineWidth: Stroke.medium)
                Text(contact.initials)
                    .textStyle(Typography.balance)
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 72, height: 72)
            .padding(.bottom, Spacing.xs)
            
            HStack(spacing: 8) {
                Text("TO")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)

                Text(contact.nickname ?? "")
                    .textStyle(Typography.sectionTitle)
                    .foregroundColor(Color.movo.textPrimary)
            }

            HStack(spacing: 8) {
                Text(contact.phoneNumber ?? "")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Account Card

    private var accountCard: some View {
        Group {
            if displayCards.isEmpty {
                HStack {
                    Text("No cards available")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                }
                .padding(Spacing.lg)
                .background(cardBackground)
            } else if displayCards.count == 1 {
                accountCardContent
            } else {
//                Button {
//                    amountFocused = false
//                    UIApplication.shared.dismissKeyboard()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//                        showAccountSheet = true
//                    }
//                } label: {
//                    accountCardContent
//                }
//                .buttonStyle(.plain)
                accountCardContent
            }
        }
    }

    private var accountCardContent: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevatedHigh)
                MovoMVSymbol().frame(width: 28, height: 28)
            }
            .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 4) {
                if let card = selectedCard {
                    let isPrimary = card.id == primaryLinkedCard?.id
                    HStack(spacing: Spacing.xs) {
                        Text(card.savingsAccountNickname ?? card.name ?? card.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.movo.textPrimary)
                        if isPrimary {
                            StatusPill("PRIMARY", variant: .accent)
                        }
                    }
                    Text(card.maskedNumber)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                    Text(card.displayBalance)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                } else {
                    Text("FROM")
                        .textStyle(Typography.eyebrow)
                        .foregroundColor(Color.movo.textTertiary)
                    Text("Select card")
                        .textStyle(Typography.cardTitle)
                        .foregroundColor(Color.movo.textDisabled)
                }
            }
            
            Spacer()
            
            //            if displayCards.count > 1 {
            //                Image(systemName: "chevron.right")
            //                    .font(.system(size: 12, weight: .semibold))
            //                    .foregroundColor(Color.movo.accent)
            //            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(cardBackground)
    }

    private var accountSelectionSheet: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From Account")
                        .textStyle(Typography.sectionTitle)
                        .foregroundColor(Color.movo.textPrimary)
                    Text("Choose which account to send from")
                        .textStyle(Typography.subtitle)
                        .foregroundColor(Color.movo.textTertiary)
                }
                Spacer()
                Button { showAccountSheet = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.movo.elevated, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    ForEach(displayCards) { card in
                        Button {
                            selectedCard = card
                        } label: {
                            accountSheetRow(card: card, isSelected: selectedCard?.id == card.id)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.xxl)
                                        .fill(Color.movo.surface.opacity(0.85))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Radius.xxl)
                                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.movo.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
    }

    private func accountSheetRow(card: VCardListResponse, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.savingsAccountNickname ?? card.name ?? card.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                Text(card.maskedNumber)
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                Text(card.displayBalance)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.clear : Color.movo.border, lineWidth: Stroke.hairline * 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.movo.accent)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.movo.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
            )
    }

    // MARK: - Send Button

    private var sendButton: some View {
        PayActionButton(amount: amount, isEnabled: isValid) {
            UIApplication.shared.dismissKeyboard()
            amountFocused = false
            Task {
                await sendMoney()
            }
            //showReview()
        }
    }

    // MARK: - Actions

    private func showReview() {
        let rawPhone = contact.phoneNumber ?? ""
        let withCountry = rawPhone.hasPrefix("+1") ? rawPhone : "+1\(rawPhone.filter(\.isNumber))"
        let sanitized = PhoneNumberValidator.sanitize(withCountry)
        guard PhoneNumberValidator.isValidUSNumber(sanitized) else {
            AlertManager.shared.showError("Enter a valid phone number")
            return
        }
        showConfirmSheet = true
    }
    
    private func sendMoney() async {
        guard let fromCard = selectedCard else { return }
        guard !Task.isCancelled else { return }

        let rawPhone    = contact.phoneNumber ?? ""
        let withCountry = rawPhone.hasPrefix("+1") ? rawPhone : "+1\(rawPhone.filter(\.isNumber))"
        let sanitized   = PhoneNumberValidator.sanitize(withCountry)
        let normalizedPhone = PhoneNumberValidator.normalize(sanitized)

        //   true  → recipient is a MOVO user → .internalTransfer
        //   false / nil → external recipient → .externalTransfer
        let isInternal = recipientExists ?? false

        await achVM.sendMoneyToContact(
            fromCard: fromCard,
            toName: contact.nickname ?? contact.phoneNumber ?? "",
            normalizedPhone: normalizedPhone,
            amount: amount,
            amountText: amountText,
            description: descriptionText.isEmpty ? nil : descriptionText,
            isInternal: isInternal
        )
    }
}
