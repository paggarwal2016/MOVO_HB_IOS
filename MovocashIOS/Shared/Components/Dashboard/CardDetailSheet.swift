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
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        cardRevealBlock
                        actionTiles
                        recentActivitySection
                        bottomButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
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

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 32, height: 32)
            Spacer()
            Text("My Card")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
            Spacer()
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Card Reveal Block

    private var cardRevealBlock: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.14), Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARD NUMBER")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1)
                        Text(card.cardNumber ?? card.maskedNumber)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = card.cardNumber ?? card.maskedNumber
                        ToastManager.shared.show("Card number copied", style: .success, position: .bottom)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPIRES")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1)
                        Text(card.formattedExpiry)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVC")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1)
                        Text(card.cvc2 ?? "•••")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARDHOLDER")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1)
                        Text(card.displayName.uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("mastercard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(minHeight: 180)
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    // MARK: - Action Tiles

    private var actionTiles: some View {
        HStack(spacing: 12) {
            actionTile(
                icon: "arrow.left.arrow.right",
                iconColor: Color(red: 0.2, green: 0.78, blue: 0.5),
                iconBg: Color(red: 0.2, green: 0.78, blue: 0.5).opacity(0.15),
                label: "Transfer"
            ) {
                showTransfer = true
            }
            actionTile(
                icon: "arrow.down.circle",
                iconColor: Color(red: 0.95, green: 0.3, blue: 0.3),
                iconBg: Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.15),
                label: "Top up"
            ) {
                // TODO: Implement Top Up flow
            }
        }
    }

    @ViewBuilder
    private func actionTile(
        icon: String,
        iconColor: Color,
        iconBg: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconBg)
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.preTcolor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent activity")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.preTcolor)

            if txVM.state == .loading && txVM.transactions.isEmpty {
                AccountRowSkeleton()
            } else if txVM.transactions.isEmpty {
                Text("No recent transactions")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secTcolor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                let grouped = groupedTransactions(txVM.transactions)
                ForEach(grouped, id: \.0) { date, items in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(date)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                transactionRow(item)
                                if idx < items.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.leading, 58)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func transactionRow(_ item: TransactionItem) -> some View {
        let isPending = item.status.lowercased() == "pending"
        let isFailed  = item.status.lowercased() == "failed" || item.status.lowercased() == "declined"

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackground(for: item.type))
                    .frame(width: 42, height: 42)
                Image(systemName: iconName(for: item.type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isFailed ? Color.white.opacity(0.4) : .white)
                    .strikethrough(isFailed, color: Color.white.opacity(0.4))
                    .lineLimit(1)
                Text(shortTime(item.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.amountFormatted)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.isCredit ? Color(red: 0.2, green: 0.78, blue: 0.5) : .white)

                if isPending {
                    Text("PENDING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.15))
                        .clipShape(Capsule())
                } else if isFailed {
                    Text("FAILED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.3, blue: 0.3))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            
            PrimaryButton(image:Image(systemName: "wallet.pass"),
                          title: "Add to Apple Wallet",
                          backgroundColor: .primary,
                          action: {
                Task {
                    guard let accountId = card.savingsAccountId else { return }
                    await achVM.addVirtualCardToAppleWallet(accountId: accountId, localizedDescription: "Apple pay")
                }
            })
            
            PrimaryButton(image:Image(systemName: "trash"),
                          title: "Delete account",
                          backgroundColor: Color.preTcolor,
                          action: { showDeleteConfirm = true })
            .disabled(isDeleting)
        }
    }

    // MARK: - Helpers

    private func groupedTransactions(_ items: [TransactionItem]) -> [(String, [TransactionItem])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var groups: [(String, [TransactionItem])] = []
        var seen: [String: Int] = [:]

        for item in items {
            let label = groupLabel(for: item.date, today: today, calendar: calendar)
            if let idx = seen[label] {
                groups[idx].1.append(item)
            } else {
                seen[label] = groups.count
                groups.append((label, [item]))
            }
        }
        return groups
    }

    private func groupLabel(for date: Date, today: Date, calendar: Calendar) -> String {
        let itemDay = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: itemDay, to: today).day ?? 0
        switch diff {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        default:
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return f.string(from: date)
        }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func iconName(for type: TransactionType) -> String {
        switch type {
        case .deposit:  return "arrow.down.left"
        case .withdraw: return "arrow.up.right"
        case .payment:  return "creditcard"
        case .transfer: return "arrow.left.arrow.right"
        case .unknown:  return "questionmark"
        }
    }

    private func iconBackground(for type: TransactionType) -> Color {
        switch type {
        case .deposit:  return Color(red: 0.2, green: 0.78, blue: 0.5).opacity(0.8)
        case .withdraw: return Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.8)
        case .payment:  return Color(red: 0.4, green: 0.4, blue: 0.9).opacity(0.8)
        case .transfer: return Color(red: 0.9, green: 0.6, blue: 0.1).opacity(0.8)
        case .unknown:  return Color.white.opacity(0.2)
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
