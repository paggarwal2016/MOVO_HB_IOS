//
//  FundAccountView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 09/04/26.
//

import SwiftUI

// MARK: - Mode

enum FundAccountMode {
    case dashboard
    case profile
    /// Post-KYC onboarding deposit. Behaves like `.dashboard` (external → MOVO) but
    /// self-loads both the external accounts and the MOVO primary via API, and lands
    /// on the dashboard when finished (success or back).
    case onboardingDeposit
}

// MARK: - View

struct FundAccountView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @StateObject private var vm: ACHViewModel
    @StateObject private var plaidVM: PlaidAchViewModel
    @StateObject private var transactionVM: TransactionViewModel
    @StateObject private var vcardVM: VCardViewModel

    let onSuccess: () -> Void
    let onAccountLinked: () -> Void
    private let initialAccounts: [ACHAccount]
    private let mode: FundAccountMode
    /// MOVO primary supplied by the caller. In `.onboardingDeposit` mode this is nil
    /// and the screen self-loads it (see `loadedPrimaryAccount` / `loadOnboardingAccounts`).
    private let injectedPrimaryAccount: SavingsAccountInfo?

    init(container: AppContainer, initialAccounts: [ACHAccount] = [], primaryAccount: SavingsAccountInfo? = nil, mode: FundAccountMode = .dashboard, onSuccess: @escaping () -> Void = {}, onAccountLinked: @escaping () -> Void = {}) {
        self.initialAccounts = initialAccounts
        self.mode = mode
        _vm = StateObject(wrappedValue: container.makeACHViewModel())
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _transactionVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        self.injectedPrimaryAccount = primaryAccount
        self.onSuccess = onSuccess
        self.onAccountLinked = onAccountLinked
    }

    /// Resolved MOVO primary — injected by the caller, or self-loaded in onboarding mode.
    private var primaryAccount: SavingsAccountInfo? { injectedPrimaryAccount ?? loadedPrimaryAccount }

    private var isProfileMode: Bool {
        if case .profile = mode { return true }
        return false
    }

    private var isOnboarding: Bool {
        if case .onboardingDeposit = mode { return true }
        return false
    }

    @State private var selectedAccount: ACHAccount?
    @State private var loadedPrimaryAccount: SavingsAccountInfo?
    @State private var amount: String = "0"
    @State private var showConfirmSheet: Bool = false
    @State private var showAccountSheet: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var isConnecting: Bool = false
    @State private var successData: SuccessConfirmation?
    @State private var transferTask: Task<Void, Never>?
    @FocusState private var isAmountFocused: Bool

    private var enteredAmount: Decimal { Decimal(string: amount) ?? 0 }

    private var amountExceedsBalance: Bool {
        if isProfileMode {
            return enteredAmount > (primaryAccount?.availableBalance ?? 0)
        }
        guard let account = selectedAccount else { return false }
        return enteredAmount > account.plaidAccountBalance
    }

    private var isFormValid: Bool {
        guard selectedAccount != nil, enteredAmount > 0 else { return false }
        if isProfileMode { return true }
        return !amountExceedsBalance
    }

    private var sortedAccounts: [ACHAccount] {
        vm.accounts.sorted { $0.isDefault && !$1.isDefault }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()

            if vm.state == .loading && vm.accounts.isEmpty {
                SpinnerView()
            } else {
                VStack(spacing: 0) {
                    navBar
                    Spacer()

                    amountDisplay
                        .padding(.bottom, Spacing.lg)
                    Spacer()

                    transferPanel
                        .padding(.bottom, Spacing.lg)
                    Spacer()

                    transferButton
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                }
                .contentShape(Rectangle())
                .onTapGesture { isAmountFocused = false }
            }

            if isSubmitting {
                Color.black.opacity(0.45).ignoresSafeArea()
                SpinnerView()
            }
        }
        .blur(radius: showConfirmSheet ? 3 : 0)
        .blur(radius: showAccountSheet ? 3 : 0)
        .background(Color.movo.background.ignoresSafeArea())
        .onAppear {
            vm.seed(accounts: initialAccounts)
            if selectedAccount == nil {
                selectedAccount = vm.accounts.first(where: { $0.isDefault }) ?? vm.accounts.first
            }
        }
        .task {
            if isOnboarding {
                await loadOnboardingAccounts()
            } else {
                await vm.fetchAccounts()
            }
        }
        .onChange(of: vm.accounts) { accounts in
            guard selectedAccount == nil else { return }
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
        }
        .onChange(of: isAmountFocused) { focused in
            if focused && amount == "0" { amount = "" }
            if !focused && amount.isEmpty { amount = "0" }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            transferTask?.cancel()
            transferTask = nil
            isSubmitting = false
            showConfirmSheet = false
            showAccountSheet = false
            (securedDismiss ?? dismiss)()
        }
        .sheet(isPresented: $showConfirmSheet) {
            let fromName = isProfileMode ? (primaryAccount?.displayName ?? "MOVO") : (selectedAccount?.accountName ?? "—")
            let fromMask = isProfileMode ? primaryAccount?.maskedAccountNumber : selectedAccount.map { "••\($0.accountNumber.suffix(4))" }
            let toName   = isProfileMode ? (selectedAccount?.accountName ?? "—") : (primaryAccount?.displayName ?? "MOVO")
            let toMask   = isProfileMode ? selectedAccount.map { "••\($0.accountNumber.suffix(4))" } : primaryAccount?.maskedAccountNumber
            ConfirmationBottomSheet(
                channel: .external,
                amount: amount,
                fromName: fromName,
                fromMask: fromMask,
                toName: toName,
                toMask: toMask,
                isLoading: vm.state == .loading,
                onCancel: { showConfirmSheet = false },
                onConfirm: {
                    guard let account = selectedAccount else { return }
                    showConfirmSheet = false
                    isSubmitting = true
                    transferTask = Task {
                        var success = false
                        var referenceCode = "MV-\(Date.now.formatted(.iso8601).prefix(10).replacingOccurrences(of: "-", with: ""))-\(String(UUID().uuidString.prefix(4)))"
                        if isProfileMode {
                            guard let primary = primaryAccount else { isSubmitting = false; return }
                            let request = TransactionRequest.Withdrawal(
                                accountId: account.achAccountId,
                                transactionAmount: Double(amount) ?? 0,
                                savingsAccountId: primary.id
                            )
                            if let response = try? await transactionVM.postWithdrawal(request: request) {
                                success = true
                                referenceCode = "MV-\(response.transactionId)"
                            }
                        } else {
                            let request = ACHRequest(
                                amount: Int(amount) ?? 0,
                                achAccountId: account.achAccountId,
                                userAction: "SUBMITS-ACH-DEPOSIT"
                            )
                            success = await vm.initiateTransfer(request: request)
                        }
                        guard !Task.isCancelled else { return }
                        isSubmitting = false
                        if success {
                            let dateText = Date.now.formatted(date: .long, time: .shortened)
                            successData = SuccessConfirmation(
                                channel: .external,
                                amount: Decimal(string: amount) ?? 0,
                                fromAccountName: fromName,
                                fromAccountMask: fromMask ?? "—",
                                toAccountName: toName,
                                toAccountMask: toMask ?? "—",
                                arrivesText: "1–3 business days",
                                dateText: dateText,
                                referenceCode: referenceCode
                            )
                        }
                    }
                }
            )
            .padding(.top, 30)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
        }
        .sheet(isPresented: $showAccountSheet) {
            let rowHeight: CGFloat = 86
            let fixedHeight = CGFloat(sortedAccounts.count) * rowHeight + 80
            BankAccountPickerSheet(accounts: sortedAccounts, selected: $selectedAccount)
                .presentationDetents(sortedAccounts.count > 5 ? [.medium, .large] : [.height(fixedHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
        }
        .fullScreenCover(item: $successData, onDismiss: {
            onSuccess()
            (securedDismiss ?? dismiss)()
        }) { data in
            SuccessConfirmationView(
                viewModel: SuccessConfirmationViewModel(success: data) {
                    successData = nil
                }
            )
        }
    }

    // MARK: - Onboarding self-load

    /// Onboarding-only: load both sides of the transfer from the network.
    ///  • FROM — external linked accounts via `vm.fetchAccounts()` (ACH).
    ///  • TO   — MOVO primary via `VCardAPI.getVCardsPrimary` (`fetchPrimaryCard()`),
    ///    mapped to a display `SavingsAccountInfo`.
    private func loadOnboardingAccounts() async {
        await vm.fetchAccounts()
        guard loadedPrimaryAccount == nil else { return }
        if let card = try? await vcardVM.fetchPrimaryCard() {
            loadedPrimaryAccount = SavingsAccountInfo(primaryCard: card)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") {
                // Onboarding: leaving the fund step lands on the dashboard rather than
                // popping back to the bank-link screen.
                if isOnboarding { onSuccess() }
                else { (securedDismiss ?? dismiss)() }
            }
            Spacer()
            Text(isProfileMode ? "Withdraw Funds" : "Fund Account")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$")
                .textStyle(Typography.amountPrefix)
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)

            let parts = amount.split(separator: ".")
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
        .onTapGesture { showAmountPad() }
        .overlay(
            TextField("", text: $amount)
                .keyboardType(.decimalPad)
                .focused($isAmountFocused)
                .opacity(0)
        )
    }

    // MARK: - Transfer Panel (From / To rows)

    private var transferPanel: some View {
        VStack(spacing: 0) {
            // FROM
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("From")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)

                if isProfileMode {
                    // Withdraw: FROM = Movo primary (fixed)
                    accountRow(
                        avatar: movoAvatar,
                        name: primaryAccount?.displayName ?? "MOVO",
                        number: primaryAccount?.maskedAccountNumber ?? "",
                        amount: primaryAccount?.formattedBalance ?? "",
                        showChevron: false,
                        isPrimary: true
                    )
                } else if vm.state == .loading && sortedAccounts.isEmpty {
                    HStack {
                        ProgressView().tint(Color.movo.textSecondary)
                        Text("Loading accounts…")
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                } else if sortedAccounts.isEmpty {
                    Button {
                        Task {
                            isConnecting = true
                            defer { isConnecting = false }
                            do {
                                try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
                            } catch {
                                AlertManager.shared.showError("Unable to initialize. Please try again.")
                                return
                            }
                            let linked = await plaidVM.startPlaidLink()
                            if let linked {
                                vm.addLinkedAccount(linked)
                                onAccountLinked()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            CircleIconAvatar(systemName: "plus", size: 44, tint: .accent)
                            Text(isConnecting || plaidVM.state == .loading ? "Connecting..." : "Link your external account")
                                .textStyle(Typography.body)
                                .foregroundStyle(Color.movo.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.movo.accent)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, Spacing.lg)
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting || plaidVM.state == .loading)
                } else {
                    Button {
                        isAmountFocused = false
                        if sortedAccounts.count > 1 { showAccountSheet = true }
                    } label: {
                        accountRow(
                            avatar: bankInitialsAvatar,
                            name: selectedAccount?.institutionName ?? "—",
                            number: "••\((selectedAccount?.accountNumber ?? "").suffix(4))",
                            amount: selectedAccount?.formattedBalance ?? "",
                            showChevron: sortedAccounts.count > 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(Color.movo.cardBorder)
                .frame(height: Stroke.hairline)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 5)
                .padding(.bottom, 10)

            // TO
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("To")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)

                if isProfileMode {
                    // Withdraw: TO = ACH account picker
                    if vm.state == .loading && sortedAccounts.isEmpty {
                        HStack {
                            ProgressView().tint(Color.movo.textSecondary)
                            Text("Loading accounts…")
                                .font(.system(size: 13))
                                .foregroundColor(Color.movo.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    } else {
                        Button {
                            isAmountFocused = false
                            if sortedAccounts.count > 1 { showAccountSheet = true }
                        } label: {
                            accountRow(
                                avatar: bankInitialsAvatar,
                                name: selectedAccount?.institutionName ?? "—",
                                number: "••\((selectedAccount?.accountNumber ?? "").suffix(4))",
                                amount: selectedAccount?.formattedBalance ?? "",
                                showChevron: sortedAccounts.count > 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    accountRow(
                        avatar: movoAvatar,
                        name: primaryAccount?.displayName ?? "MOVO",
                        number: primaryAccount?.maskedAccountNumber ?? "",
                        amount: primaryAccount?.formattedBalance ?? "",
                        showChevron: false,
                        isPrimary: true
                    )
                }
            }
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
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Account Row

    private func accountRow(
        avatar: some View,
        name: String,
        number: String,
        amount: String,
        showChevron: Bool,
        isPrimary: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.md) {
            AnyView(avatar)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.sm) {
                    Text(name)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    if isPrimary {
                        StatusPill("PRIMARY", variant: .accent)
                    }
                }
                Text(number)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                if !amount.isEmpty {
                    Text(amount)
                        .textStyle(Typography.subtitle)
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

    // MARK: - Avatars

    private var bankInitialsAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )

            if let image = selectedAccount?.logoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(selectedAccount?.institutionName.prefix(2).uppercased() ?? "••")
                   .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
            }
        }
    }

    private var movoAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
            MovoMVSymbol()
                .frame(width: 28, height: 28)
        }
    }

    // MARK: - Transfer Button

    private var transferButton: some View {
        Button {
            guard isFormValid else { return }
            isAmountFocused = false
            UIApplication.shared.dismissKeyboard()
            showConfirmSheet = true
        } label: {
            Group {
                if vm.state == .loading {
                    ProgressView().tint(Color.movo.onAccent)
                } else {
                    Text("Transfer")
                        .textStyle(Typography.buttonLarge)
                        .foregroundColor(Color.movo.onAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isFormValid ? Color.movo.accent : Color.movo.accent.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid)
    }

    // MARK: - Amount Entry (number pad)

    private func showAmountPad() {
        isAmountFocused = true
    }

}

// MARK: - Bank Account Picker Sheet

struct BankAccountPickerSheet: View {
    let accounts: [ACHAccount]
    @Binding var selected: ACHAccount?
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    ForEach(accounts, id: \.achAccountId) { account in
                        let isSelected = selected?.achAccountId == account.achAccountId
                        Button {
                            selected = account
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Radius.button)
                                        .fill(Color.movo.elevatedHigh)
                                    if let image = account.logoImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        Text(account.institutionName.prefix(2).uppercased())
                                              .textStyle(Typography.body)
                                            .foregroundColor(Color.movo.textPrimary)
                                    }
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.institutionName)
                                       .textStyle(Typography.cardTitle)
                                       .foregroundColor(Color.movo.textPrimary)
                                    Text("\(account.accountName) · ••\(account.accountNumber.suffix(4))")
                                         .textStyle(Typography.subtitle)
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
            .scrollContentBackground(.hidden)
            .background(Color.movo.background.ignoresSafeArea())
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.movo.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

// MARK: - SavingsAccountInfo from primary VCard

private extension SavingsAccountInfo {
    /// Builds a display-oriented MOVO primary from the primary VCard
    /// (`VCardAPI.getVCardsPrimary`). Used only by FundAccountView's onboarding "to"
    /// row, which needs the account name, masked number and available balance.
    init(primaryCard card: VCardListResponse) {
        id = card.savingsAccountId ?? 0
        accountNumber = card.lastFour ?? ""
        clientName = card.name ?? ""
        status = .active
        accountBalance = Decimal(card.savingsAccountBalance ?? 0)
        availableBalance = Decimal(card.savingsAccountAvailableBalance ?? card.savingsAccountBalance ?? 0)
        clientId = 0
        nickname = card.savingsAccountNickname.flatMap { $0.isEmpty ? nil : $0 }
        isPrimary = true
        routingNumber = nil
    }
}
