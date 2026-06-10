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
    @State private var isDeleting = false
    @State private var showTransfer = false
    @State private var showAllTransactions = false
    @State private var isLoading = false
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
                    cardHero
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
        }
        .navigationBarBackButtonHidden(true)
        .alert("Delete Card", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteTask = Task { await deleteCard() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
        .sheet(isPresented: $showAllTransactions) {
            if let accountId = card.savingsAccountId {
                TransactionListView(
                    container: container,
                    accountId: accountId,
                    mode: .individual,
                    initialMax: 500
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            walletTask?.cancel()
            walletTask = nil
            deleteTask?.cancel()
            deleteTask = nil
            refreshTask?.cancel()
            refreshTask = nil
            showDeleteConfirm = false
            showTransfer = false
            showAllTransactions = false
            isLoading = false
            isDeleting = false
            (securedDismiss ?? dismiss)()
        }
        .sheet(isPresented: $showTransfer) {
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            isLoading = true
            await loadRecentTransactions()
            isLoading = false
        }
        .onDisappear {
            // Refresh the Dashboard on the way back only if something changed here.
            if hasChanges { onChanged?() }
        }
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
                        AlertManager.shared.showError("Unable to initialize. Please try again.")
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
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 16, weight: .medium))
                    Text("Add to Apple Wallet")
                        .textStyle(Typography.bodyCompact)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.movo.background)
                .frame(width: transferWidth)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.movo.accent)
                )
            }
            .buttonStyle(.plain)

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
    
    public func copyCardNumber() {
        let text = card.fullNumberPasteboard
        UIPasteboard.general.string = text
        ToastManager.shared.show("Card number copied", style: .success, position: .bottom)
    }
    
    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { (securedDismiss ?? dismiss)() }
            Spacer()
            Text("My Card")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
    
    private var cardHero: some View {
        MovoCardHero(card: displayCard)
            .frame(width: 220)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: .infinity)
    }
    
    public struct MovoCardHero: View {
        public let card: VCardListResponse

        private var formattedBalance: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = card.currencyCode
            formatter.maximumFractionDigits = 2
            return formatter.string(from: card.balance as NSDecimalNumber) ?? "—"
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                
                // Top: brand lockup + status pill
                HStack(alignment: .center) {
                    HStack(spacing: 6) {

                        MovoMVSymbol()
                            .frame(width: 22, height: 22)

                        Text("MOVOCASH")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundColor(Color.movo.onCardArtwork)
                    }
                    Spacer()
                    StatusPill(card.isActive ? "Active" : "Inactive",
                               variant: card.isActive ? .accent : .neutral)
                }

                // Balance
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow("Available balance", color: Color.movo.cardArtworkMuted)
                    Text(card.displayBalance)
                        .textStyle(Typography.cardHero)
                        .foregroundColor(Color.movo.onCardArtwork)
                        .monospacedDigit()
                }
                .padding(.top, Spacing.lg)

                // Chip + contactless
                HStack(spacing: 14) {
                    CardChip()
                        .frame(width: 44, height: 34)
                    ContactlessIcon()
                        .frame(width: 22, height: 22)
                }
                .padding(.top, Spacing.md)

                Spacer(minLength: 8)

                // Card number
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARD NUMBER")
                        .font(.system(size: 7.5, weight: .medium))
                        .tracking(1.0)
                        .foregroundColor(Color.movo.cardArtworkMuted)
                    Text(card.maskedNumber)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(1.3)
                        .foregroundColor(Color.movo.onCardArtwork)
                }

                // Bottom: DEBIT + Mastercard
                HStack(alignment: .bottom) {
                    Text(card.tier.uppercased())
                        .font(.system(size: 8.5, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color.movo.cardArtworkMuted)
                    Spacer()
                    MastercardMark()
                }
                .padding(.top, Spacing.lg)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .aspectRatio(0.63, contentMode: .fit)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.cardArtworkBorder, lineWidth: Stroke.hairline)
            )
            .cardArtworkShadow()
        }
        
        private var cardBackground: some View {
            ZStack {
                // Base gradient — brand-locked card art (constant in both light and dark mode)
                LinearGradient(
                    colors: [Color.movo.cardArtworkBorder, Color.movo.cardArtwork],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Top shimmer
                RadialGradient(
                    colors: [Color.movo.onCardArtwork.opacity(0.10), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 180
                )
                .blendMode(.overlay)
            }
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

    private var cardNumberRow: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Card number")
                Text(formattedCardNumber)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.movo.textPrimary)
                    .tracking(1.5)
                Text("Exp \(card.expiration ?? "") · CVC \(card.cvc2 ?? "")")
                    .textStyle(Typography.captionSmall)
                    .foregroundColor(Color.movo.textTertiary)
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
