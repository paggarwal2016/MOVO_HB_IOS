//
//  CardDetailSheet.swift
//  MovocashIOS
//

import SwiftUI

struct CardDetailSheet: View {
    
    let card: VCardListResponse
    let primaryAccountId: Int?
    /// Primary card — refreshed from the card details API after a transfer.
    @State private var primaryLinkedCard: VCardListResponse?
    /// Primary account from the Dashboard — its `clientId` is the user-level id
    /// used to execute transfers (the card list carries no clientId, so this is
    /// not refreshed by the card details API).
    @State private var primaryAccount: SavingsAccountInfo?
    /// Card list (transfer destinations) — refreshed from the card details API.
    @State private var cards: [VCardListResponse]
    let savingVM: SavingsAccountViewModel
    let container: AppContainer
    var canDelete: Bool
    var onDeleted: () -> Void
    /// Called on return from the sheet when something changed here (a completed
    /// transfer or an Apple Wallet add), so the Dashboard can refresh.
    var onChanged: (() -> Void)? = nil

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    
    @State private var showDeleteConfirm = false
    @State private var showEditNickname = false
    @State private var isDeleting = false
    @State private var showTransfer = false
    @State private var showAllTransactions = false
    @State private var isLoading = false
    @State private var showFullCardNumber = false
    /// Revealed security code — held transiently in view state only. Never cached,
    /// logged, or persisted; cleared when the sheet closes or the user hides it.
    @State private var revealedCvc: String?
    @State private var isRevealingCvc = false
    @State private var cvcTask: Task<Void, Never>?
    @State private var walletTask: Task<Void, Never>?
    @State private var deleteTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?
    /// Set when a transfer or Apple Wallet add succeeds here; triggers a Dashboard
    /// refresh on the way back via `onChanged`.
    @State private var hasChanges = false
    /// Latest card details fetched after a completed transfer. Falls back to the
    /// `card` passed in from the Dashboard until a refresh succeeds.
    @State private var liveCard: VCardListResponse?
    @StateObject private var txVM: TransactionViewModel
    @StateObject private var achVM: PlaidAchViewModel
    @StateObject private var vcardVM: VCardViewModel
    
    init(
        card: VCardListResponse,
        primaryAccountId: Int?,
        primaryLinkedCard: VCardListResponse? = nil,
        primaryAccount: SavingsAccountInfo? = nil,
        cards: [VCardListResponse] = [],
        savingVM: SavingsAccountViewModel,
        container: AppContainer,
        canDelete: Bool = true,
        onDeleted: @escaping () -> Void,
        onChanged: (() -> Void)? = nil
    ) {
        self.card = card
        self.primaryAccountId = primaryAccountId
        _primaryLinkedCard = State(initialValue: primaryLinkedCard)
        _primaryAccount = State(initialValue: primaryAccount)
        _cards = State(initialValue: cards)
        self.savingVM = savingVM
        self.container = container
        self.canDelete = canDelete
        self.onDeleted = onDeleted
        self.onChanged = onChanged
        _txVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
    }

    /// The card currently shown. Reflects the latest refresh once a transfer
    /// completes; otherwise the card handed down from the Dashboard.
    private var displayCard: VCardListResponse { liveCard ?? card }

    /// Wallet button title, driven by the latest eligibility check. When the card
    /// can't be added (already provisioned on this device, or unsupported) the
    /// button is disabled and reads "In Apple Wallet".
    private var walletButtonTitle: String {
        achVM.canAddToWallet ? "Add to Apple Wallet" : "In Apple Wallet"
    }

    /// Disabled state uses dedicated neutral tokens rather than dimming the accent
    /// fill with opacity (which looks washed-out); the button stays crisp and
    /// clearly reads as inactive.
    private var walletButtonFill: Color {
        achVM.canAddToWallet ? Color.movo.accent : Color.movo.elevated
    }

    private var walletButtonForeground: Color {
        achVM.canAddToWallet ? Color.movo.background : Color.movo.textDisabled
    }

    private var transferMode: TransferFlowMode {
        if card.id == primaryLinkedCard?.id {
            return .fixedFrom
        } else if let primaryCard = primaryLinkedCard {
            return .fixedBoth(toCard: primaryCard)
        }
        return .standard
    }
    
    var body: some View {
        ZStack {
            MovoBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                    cardSection
                    availableBalanceRow
                    cardNumberRow
                    cardActions
                    if txVM.transactions.count > 0 {
                        recentActivitySection
                    }
                   // if canDelete { deleteSection }
                    Spacer().frame(height: Spacing.xxl)
                }
            }

            StatusBarScrim()

            if isLoading || isDeleting {
                Color.black.opacity(0.45).ignoresSafeArea()
                SpinnerView()
            }

            if showEditNickname {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showEditNickname)
        .navigationBarBackButtonHidden(true)
        .alert("Delete Card", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteTask = Task { await deleteCard() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            if let accountId = card.savingsAccountId {
                TransactionListView(
                    container: container,
                    accountId: accountId,
                    mode: .individual,
                    initialMax: 50
                )
            }
        }
        .onSessionExpired {
            // Cancel in-flight wallet/delete/refresh work only; RootView navigates to login.
            walletTask?.cancel()
            walletTask = nil
            cvcTask?.cancel()
            cvcTask = nil
            revealedCvc = nil
            deleteTask?.cancel()
            deleteTask = nil
            refreshTask?.cancel()
            refreshTask = nil
        }
        .fullScreenCover(isPresented: $showTransfer) {
            // The transfer uses the card list directly; `clientId` (user-level) is
            // the only value not carried on the card, so it comes from the primary
            // account passed down from the Dashboard.
            if let clientId = primaryAccount?.clientId {
                InternalTransferView(
                    mode: transferMode,
                    toClientId: clientId,
                    fromAccount: nil,
                    nonPrimaryAccounts: [],
                    preselectedFromCard: displayCard,
                    primaryLinkedCard: primaryLinkedCard,
                    initialCards: cards,
                    container: container,
                    onDismiss: {
                        showTransfer = false
                        hasChanges = true
                        refreshTask = Task { await refreshCardDetails() }
                    }
                )
            }
        }
        .task {
            isLoading = true
            await loadRecentTransactions()
            isLoading = false
        }
        .task {
            await refreshWalletEligibility()
        }
        .sheet(isPresented: $showEditNickname) {
            EditNicknameView(currentNickname: cardNickname) { newValue in
                saveNickname(newValue)
            }
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.movo.cardSurface)
            .presentationCornerRadius(Radius.sheet)
        }
        .onDisappear {
            // Refresh the Dashboard on the way back only if something changed here.
            if hasChanges { onChanged?() }
        }
    }

    private var cardNickname: String {
        (displayCard.savingsAccountNickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasNickname: Bool { !cardNickname.isEmpty }

    private func saveNickname(_ newValue: String) {
        guard let accountId = displayCard.savingsAccountId else { return }
        refreshTask = Task {
            await savingVM.updateNickname(name: newValue, accountId: accountId, primaryAccountId: primaryLinkedCard?.savingsAccountId ?? 0)
            guard !Task.isCancelled else { return }
            hasChanges = true
            await refreshCardDetails()
        }
    }

    /// Refreshes the SDK configuration, then re-evaluates Apple Wallet eligibility
    /// so the "Add to Apple Wallet" button's enabled state reflects the latest
    /// status every time this screen is shown. Runs via `.task` on appear.
    private func refreshWalletEligibility() async {
        do {
            try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
        } catch {
            SecureLogger.error("[Wallet] SDK config for eligibility failed: \(error.localizedDescription)", category: .payment)
            achVM.canAddToWallet = false
            return
        }
        achVM.checkCanAddToWallet(
            primaryAccountNumberSuffix: card.lastFour ?? "",
            localizedDescription: "Apple Pay"
        )
    }

    /// Loads the latest 10 transactions for this card's savings account.
    private func loadRecentTransactions() async {
        guard let accountId = card.savingsAccountId else { return }
        var filter = TransactionFilter(accountId: accountId)
        filter.max       = 10
        filter.limit     = 10
        filter.sortBy    = .createdAt
        filter.sortOrder = .desc
        await txVM.loadTransactionsFiltered(filter: filter, paginated: false)
    }

    /// Refreshes the card details and recent activity after a completed transfer.
    /// On a card-details failure we keep the existing card and still refresh
    /// transactions, so the screen never ends up empty.
    private func refreshCardDetails() async {
        isLoading = true
        defer { isLoading = false }
        // Re-fetch the full card list and re-derive everything by savings account id.
        if let refreshed = try? await vcardVM.getVCardsAll() {
            let enabled = refreshed.filter { $0.enabled == true }
            // Refresh the displayed card (feeds `displayCard` → the card hero).
            if let accountId = card.savingsAccountId,
               let updated = enabled.first(where: { $0.savingsAccountId == accountId }) {
                liveCard = updated
            }
            if !enabled.isEmpty {
                // Primary card identified by matching savings id; the remaining
                // cards feed the transfer's "from"/"to" destination lists.
                primaryLinkedCard = enabled.first(where: { $0.savingsAccountId == primaryAccountId })
                cards = enabled.filter { $0.savingsAccountId != primaryAccountId }
            }
        }
        await loadRecentTransactions()
    }
    
    
    private var cardActions: some View {
        let availableWidth = UIScreen.main.bounds.width - 2 * Spacing.screenHorizontal
        let transferWidth = (availableWidth - 55) * 3 / 4

        return HStack(spacing: Spacing.sm) {
            Button(action: {
                walletTask = Task {
                    guard let accountId = card.savingsAccountId else { return }
                    isLoading = true
                    defer { isLoading = false }
                    do {
                        try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
                    } catch {
                        AlertManager.shared.showError(error.localizedDescription)
                        return
                    }
                    await achVM.addVirtualCardToAppleWallet(
                        accountId: accountId,
                        localizedDescription: "Apple Pay"
                    )
                    hasChanges = true
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    Group {
                        if #available(iOS 18.0, *) {
                            Image(systemName: "wallet.bifold")
                        } else {
                            Image(systemName: "creditcard")
                        }
                    }
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(walletButtonForeground)
                    Text(walletButtonTitle)
                        .textStyle(Typography.bodyCompact)
                        .fontWeight(.semibold)
                }
                .foregroundColor(walletButtonForeground)
                .frame(width: transferWidth)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(walletButtonFill)
                )
            }
            .buttonStyle(.plain)
            .disabled(!achVM.canAddToWallet)

            Button(action: { showTransfer = true }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                    Text("Transfer")
                        .textStyle(Typography.bodyCompact)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.movo.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.movo.elevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.xl)
    }
    
    private var deleteSection: some View {
        Button(action: { showDeleteConfirm = true }) {
            Text("Delete card")
        }
        .buttonStyle(OutlineButtonStyle())
        .padding(.horizontal, Spacing.screenHorizontal)
    }
    
    /// Reveals the security code behind a passkey step-up, or hides it if already
    /// shown. The revealed value is kept only in transient view state.
    private func toggleCvc() {
        if revealedCvc != nil {
            revealedCvc = nil
            return
        }
        guard let accountId = card.savingsAccountId else {
            AlertManager.shared.showError("Unable to reveal security code.")
            return
        }
        cvcTask = Task {
            isRevealingCvc = true
            defer { isRevealingCvc = false }
            if let cvc = try? await achVM.revealVirtualCardCvv(accountId: accountId) {
                guard !Task.isCancelled else { return }
                revealedCvc = cvc
            }
        }
    }

    public func copyCardNumber() {
        let text = card.fullNumberPasteboard
        UIPasteboard.general.string = text
        ToastManager.shared.show("Card number copied", style: .success, position: .bottom)
    }
    
    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: Spacing.sm) {
            CircularNavButton(systemName: "chevron.left") { (securedDismiss ?? dismiss)() }
            Text(hasNickname ? cardNickname : "My Card")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Button(action: { showEditNickname = true }) {
                MovoEditIcon(size: 18)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
    
    // MARK: - Card section (nickname row + card with balance overlay)
    
    private var cardSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Card image with balance overlaid — right side, below "HERRING BANK" text
            Image("CardFrontHerring")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .frame(width: 280)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity)
    }

    public struct MovoCardHero: View {
        public let card: VCardListResponse

        public var body: some View {
            Image("CardFrontHerring")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    /// Card number grouped into blocks of four digits, e.g. "5194 5301 0000 9977".
    private var formattedCardNumber: String {
        guard let number = card.cardNumber, !number.isEmpty else { return "" }
        return stride(from: 0, to: number.count, by: 4).map { offset in
            let start = number.index(number.startIndex, offsetBy: offset)
            let end = number.index(start, offsetBy: 4, limitedBy: number.endIndex) ?? number.endIndex
            return String(number[start..<end])
        }
        .joined(separator: " ")
    }

    /// Last-four-only display: "•••• •••• •••• 9944"
    private var maskedCardNumber: String {
        guard let number = card.cardNumber, number.count >= 4 else { return "•••• •••• •••• ••••" }
        let lastFour = String(number.suffix(4))
        return "•••• •••• •••• \(lastFour)"
    }

    private var availableBalanceRow: some View {
        HStack {
            Eyebrow("Available Balance")
            Spacer()
            BalanceText(
                amount: displayCard.availableBalance,
                dollarSize: 18,
                centsSize: 13,
                centsOpacity: 1.0
            )
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.lg)
    }

    private var cardNumberRow: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Card number")
                HStack(spacing: Spacing.sm) {
                    Text(showFullCardNumber ? formattedCardNumber : maskedCardNumber)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.movo.textPrimary)
                        .tracking(1.5)
                    Button(action: { showFullCardNumber.toggle() }) {
                        Image(systemName: showFullCardNumber ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.movo.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showFullCardNumber ? "Hide card number" : "Show card number")
                }
                HStack(spacing: 4) {
                    Text("Exp \(card.expiryMMYY) · CVC \(revealedCvc ?? "•••")")
                        .textStyle(Typography.captionSmall)
                        .foregroundColor(Color.movo.textTertiary)
                    Button(action: toggleCvc) {
                        if isRevealingCvc {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: revealedCvc == nil ? "eye" : "eye.slash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.movo.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRevealingCvc)
                    .accessibilityLabel(revealedCvc == nil ? "Reveal security code" : "Hide security code")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button(action: copyCardNumber) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.movo.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .fill(Color.movo.accentTint)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.button)
                                    .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.lg)
    }
    
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Eyebrow("Recent activity")
                Spacer()
                if txVM.transactions.count >= 10 {
                    Button("See all") { showAllTransactions = true }
                        .font(Typography.captionSmall.font)
                        .foregroundColor(Color.movo.accent)
                }
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(txVM.transactions.enumerated()), id: \.element.id) { index, item in
                    ActivityRow(item: item)
                    if index < txVM.transactions.count - 1 {
                        Rectangle()
                            .fill(Color.movo.cardBorder)
                            .frame(height: Stroke.hairline)
                            .padding(.horizontal, Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .strokeBorder(Color.movo.cardBorder, lineWidth: Stroke.hairline)
                    )
            )
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.lg)
    }
    
    private struct ActivityRow: View {
        let item: TransactionItem
        
        private var formattedAmount: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let prefix = item.isCredit ? "+" : "−"
            let formatted = formatter.string(from: item.amount as NSDecimalNumber) ?? "—"
            return "\(prefix)\(formatted)"
        }
        
        private var formattedDate: String {
            let calendar = Calendar.current
            if calendar.isDateInToday(item.date)     { return "Today" }
            if calendar.isDateInYesterday(item.date) { return "Yesterday" }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: item.date)
        }

        private var amountColor: Color {
            item.type == .deposit ? Color.movo.accent : Color.movo.textPrimary
        }
        
        private var iconSystemName: String {
            switch item.type {
            case .deposit:         return "arrow.down.left"
            case .withdraw:        return "arrow.up.right"
            case .payment:         return "creditcard"
            case .transfer:        return "arrow.left.arrow.right"
            case .unknown:         return "questionmark"
            }
        }
        
        var body: some View {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.movo.elevated, Color.movo.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Circle()
                        .strokeBorder(
                            item.type == .deposit ? Color.movo.accent : Color.movo.borderStrong,
                            lineWidth: Stroke.hairline
                        )
                    Image(systemName: iconSystemName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                }
                .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .textStyle(Typography.bodyCompact)
                        .foregroundColor(Color.movo.textPrimary)
                    Text(formattedDate)
                        .textStyle(Typography.captionSmall)
                        .foregroundColor(Color.movo.textTertiary)
                }
                
                Spacer()
                
                Text(formattedAmount)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(amountColor)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
    }
    
    // MARK: - Delete
    
    private func deleteCard() async {
        guard let primaryId = primaryAccountId,
              let accountId = card.savingsAccountId else {
            ToastManager.shared.show("Unable to delete card.", style: .error, position: .bottom)
            return
        }
        isDeleting = true
        do {
            _ = try await savingVM.deleteSavingAccount(
                request: SavingsAccountRequest.DeleteAccount(
                    targetAccountId: primaryId,
                    accountId: accountId,
                    userAction: "VCARD-DELETE"
                )
            )
            guard !Task.isCancelled else { return }
            ToastManager.shared.show("Card deleted.", style: .success, position: .bottom)
            (securedDismiss ?? dismiss)()
            onDeleted()
        } catch {
            guard !Task.isCancelled else { return }
            // error surfaced via BaseViewModel toast
        }
        isDeleting = false
    }
}
