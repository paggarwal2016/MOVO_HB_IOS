//
//  CardDetailSheet.swift
//  MovocashIOS
//

import SwiftUI

struct CardDetailSheet: View {
    
    let card: VCardListResponse
    let primaryAccountId: Int?
    let savingVM: SavingsAccountViewModel
    let container: AppContainer
    var onDeleted: () -> Void
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showTransfer = false
    @StateObject private var txVM: TransactionViewModel
    @StateObject private var achVM: PlaidAchViewModel
    
    init(
        card: VCardListResponse,
        primaryAccountId: Int?,
        savingVM: SavingsAccountViewModel,
        container: AppContainer,
        onDeleted: @escaping () -> Void
    ) {
        self.card = card
        self.primaryAccountId = primaryAccountId
        self.savingVM = savingVM
        self.container = container
        self.onDeleted = onDeleted
        _txVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                    cardHero
                    cardNumberRow
                    appleWalletButton
                    quickActions
                    recentActivitySection
                    deleteSection
                    Spacer().frame(height: Spacing.xxl)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Delete Card", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteCard() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
        .sheet(isPresented: $showTransfer) {
            let accounts = savingVM.accountList?.data.accounts ?? []
            let cardAccount = accounts.first(where: { $0.id == card.savingsAccountId })
            let primaryAccount = accounts.first(where: { $0.isPrimary })
            let fromAccount = cardAccount ?? primaryAccount
            if let fromAccount {
                InternalTransferView(
                    toClientId: fromAccount.clientId,
                    fromAccount: fromAccount,
                    nonPrimaryAccounts: accounts.filter { $0.id != fromAccount.id },
                    preselectedFromCard: card,
                    container: container,
                    onDismiss: { showTransfer = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            let accountId = card.savingsAccountId
            let needsAccounts = savingVM.accountList == nil
            async let transactions: () = {
                guard let accountId else { return }
                await txVM.loadTransactions(max: 10, accountId: accountId)
            }()
            async let accounts: () = {
                guard needsAccounts else { return }
                await savingVM.loadAccounts()
            }()
            _ = await (transactions, accounts)
        }
    }
    
    
    private var appleWalletButton: some View {
        Button(action: {
            Task {
                guard let accountId = card.savingsAccountId else { return }
                await achVM.addVirtualCardToAppleWallet(
                    accountId: accountId,
                    localizedDescription: "Apple Pay"
                )
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wallet.pass")
                    .font(.system(size: 18, weight: .medium))
                Text("Add to Apple Wallet")
                    .textStyle(Typography.bodyCompact)
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color.movo.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.movo.textPrimary)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.xl)
    }
    
    private var deleteSection: some View {
        Button(action: { showDeleteConfirm = true }) {
            Text("Delete card")
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.xs)
    }
    
    public func copyCardNumber() {
        let text = card.fullNumberPasteboard
        UIPasteboard.general.string = text
        ToastManager.shared.show("Card number copied", style: .success, position: .bottom)
    }
    
    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
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
        MovoCardHero(card: card)
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
                        MLogo()
                            .frame(width: 22, height: 22)
                        Text("MOVOCASH")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundColor(Color.movo.textPrimary)
                    }
                    Spacer()
                    StatusPill(card.isActive ? "Active" : "Inactive",
                               variant: card.isActive ? .accent : .neutral)
                }
                
                // Balance
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow("Available balance")
                    Text(formattedBalance)
                        .textStyle(Typography.cardHero)
                        .foregroundColor(Color.movo.textPrimary)
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
                        .foregroundColor(Color.movo.textTertiary)
                    Text(card.maskedNumber)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(1.3)
                        .foregroundColor(Color.movo.textPrimary)
                }
                
                // Bottom: DEBIT + Mastercard
                HStack(alignment: .bottom) {
                    Text(card.tier.uppercased())
                        .font(.system(size: 8.5, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color.movo.textSecondary)
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
                    .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
            )
            .shadow(color: .black.opacity(0.6), radius: 25, x: 0, y: 20)
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
        }
        
        private var cardBackground: some View {
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.13),
                        Color(red: 0.04, green: 0.04, blue: 0.05),
                        Color(red: 0.02, green: 0.02, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Top shimmer
                RadialGradient(
                    colors: [Color.movo.textPrimary.opacity(0.10), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 180
                )
                .blendMode(.overlay)
            }
        }
    }
    
    
    private var cardNumberRow: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Card number")
                Text(card.cardNumber ?? "''")
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
    
    
    private var quickActions: some View {
        HStack(spacing: Spacing.sm) {
            QuickActionCell(
                icon: AnyView(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.movo.accent)
                ),
                iconBackground: Color.movo.accentTint,
                iconBorder: Color.movo.accentBorder,
                label: "Transfer",
                action: { showTransfer = true }
            )
            QuickActionCell(
                icon: AnyView(
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.movo.textSecondary)
                ),
                iconBackground: Color.movo.elevated,
                iconBorder: nil,
                label: "Add money",
                action: {}
            )
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.xl)
    }
    
    
    private struct QuickActionCell: View {
        let icon: AnyView
        let iconBackground: Color
        let iconBorder: Color?
        let label: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: Spacing.sm) {
                    icon
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.button)
                                .fill(iconBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.button)
                                        .strokeBorder(iconBorder ?? .clear, lineWidth: Stroke.hairline)
                                )
                        )
                    Text(label)
                        .textStyle(Typography.captionSmall)
                        .foregroundColor(Color.movo.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .fill(Color.movo.surface.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.heroCard)
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Eyebrow("Recent activity")
                Spacer()
                Button("See all") { /* navigate */ }
                    .font(Typography.captionSmall.font)
                    .foregroundColor(Color.movo.accent)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(txVM.transactions.enumerated()), id: \.element.id) { index, item in
                    ActivityRow(item: item)
                    if index < txVM.transactions.count - 1 {
                        Rectangle()
                            .fill(Color.movo.border)
                            .frame(height: Stroke.hairline)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .fill(Color.movo.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
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
            let prefix = item.amount < 0 ? "−" : "+"
            let value = abs(item.amount)
            let formatted = formatter.string(from: value as NSDecimalNumber) ?? "—"
            return "\(prefix)\(formatted)"
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
                    Text("12/05/2026")
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
            ToastManager.shared.show("Card deleted.", style: .success, position: .bottom)
            dismiss()
            onDeleted()
        } catch {
            ToastManager.shared.show("Failed to delete card.", style: .error, position: .bottom)
        }
        isDeleting = false
    }
}
