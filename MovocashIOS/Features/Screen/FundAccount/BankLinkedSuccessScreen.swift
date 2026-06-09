//
//  BankLinkedSuccessScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 27/05/26.
//

import SwiftUI

struct BankLinkedSuccessScreen: View {

    var account: ACHAccount?
    var onDone: () -> Void = {}

    // Optional dependencies — supplied by BankLinkedInfoScreen so the user can
    // fund directly from this screen. ManageExternalAccountsView does NOT pass
    // these (it owns its own navigation), so it falls back to the onDone path.
    var container: AppContainer? = nil
    var primaryAccount: SavingsAccountInfo? = nil
    /// Retained for source compatibility with existing call sites; the funding
    /// flow now runs in-screen, so this is no longer forwarded to FundAccountView.
    var linkedAccounts: [ACHAccount] = []
    /// Hide the balance when the account came straight from the Plaid link
    /// metadata (no balance yet) so we don't show a misleading $0.00. A real
    /// balance appears once the full account list is refreshed.
    var showBalance: Bool = true

    // MARK: - Funding state

    @State private var amountText: String = "0"
    @FocusState private var amountFocused: Bool
    @State private var showConfirmSheet: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var successData: SuccessConfirmation?
    @State private var transferTask: Task<Void, Never>?

    /// MOVO primary fetched from `VCardAPI.getVCardsPrimary` on appear. Once loaded
    /// it is the source of truth for the "To" side; the injected `primaryAccount`
    /// is only the pre-load fallback.
    @State private var loadedPrimary: SavingsAccountInfo?

    /// The destination MOVO account — prefers the freshly fetched primary card.
    private var resolvedPrimary: SavingsAccountInfo? {
        loadedPrimary ?? primaryAccount
    }

    private var amountValue: Decimal { Decimal(string: amountText) ?? 0 }

    private var isDoneEnabled: Bool {
        amountValue > 0
    }

    // MARK: - Derived display values

    private var institutionName: String {
        account?.institutionName ?? "Bank"
    }

    private var initials: String {
        String(institutionName.prefix(2)).uppercased()
    }

    private var bankName: String {
        account?.accountName ?? institutionName
    }

    private var bankMask: String? {
        account.map { "••\($0.accountNumber.suffix(4))" }
    }

    private var bankBalanceText: String {
        guard showBalance else { return "" }
        return account?.formattedBalance ?? ""
    }

    private var movoName: String {
        resolvedPrimary?.nickname ?? "Movo"
    }

    private var movoMask: String? {
        resolvedPrimary?.maskedAccountNumber
    }

    private var movoBalanceText: String {
        guard let primary = resolvedPrimary else { return "" }
        return "$\(primary.availableBalance.toCurrencyString())"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            
            MovoBackground()
            AmbientGlowView()

            VStack(spacing: 0) {

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {

                        header
                        amountSection
                        fromToCard
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xxxl)
                    .padding(.bottom, Spacing.xl)
                }
                .scrollDismissesKeyboard(.immediately)

                actionButtons
            }

            if isSubmitting {
                Color.black.opacity(0.45).ignoresSafeArea()
                SpinnerView()
            }
        }
        .blur(radius: showConfirmSheet ? 3 : 0)
        .onChange(of: amountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .external,
                amount: amountText,
                fromName: bankName,
                fromMask: bankMask,
                toName: movoName,
                toMask: movoMask,
                isLoading: isSubmitting,
                onCancel: { showConfirmSheet = false },
                onConfirm: submitDeposit
            )
            .padding(.top, 30)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
        }
        .fullScreenCover(item: $successData) { data in
            SuccessConfirmationView(
                viewModel: SuccessConfirmationViewModel(success: data) {
                    // Done → collapse the whole stack back to the dashboard in a
                    // single transition (observed by RootView / HomeTabBarView /
                    // DashboardView / PlaidLinkFlowModifier).
                    NotificationCenter.default.post(name: .returnToDashboard, object: nil)
                }
            )
        }
        // Clear local presentation state when a descendant collapses the stack.
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            transferTask?.cancel()
            transferTask = nil
            isSubmitting = false
            showConfirmSheet = false
        }
        // Load the MOVO primary from VCardAPI.getVCardsPrimary for the "To" field.
        // Works with or without an injected container (falls back to the shared
        // network) so the "To" row populates in every flow.
        .task {
            guard loadedPrimary == nil else { return }
            let vcardVM = container?.makeVCardViewModel()
                ?? VCardViewModel(network: NetworkService.shared, alertManager: AlertManager.shared)
            if let card = try? await vcardVM.fetchPrimaryCard() {
                loadedPrimary = SavingsAccountInfo(primaryCard: card)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {

            // Compact success badge (top-left)
            ZStack {
                Circle()
                    .fill(Color.movo.accentTint)
                    .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.movo.accent)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("\(institutionName) account has been linked")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Let’s initiate the transfer to the Movo account.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Amount

    private var amountSection: some View {
        AmountInputDisplay(amountText: $amountText, amountFocused: $amountFocused)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
    }

    // MARK: - From / To card

    private var fromToCard: some View {
        VStack(spacing: 0) {
            accountRow(
                label: "FROM",
                logo: bankLogoTile,
                name: bankName,
                isPrimary: false,
                mask: bankMask,
                balance: bankBalanceText
            )
            divider
            accountRow(
                label: "TO",
                logo: movoLogoTile,
                name: movoName,
                isPrimary: resolvedPrimary?.isPrimary ?? false,
                mask: movoMask,
                balance: movoBalanceText
            )
        }
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sheet)
                .fill(Color.movo.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sheet)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.movo.border)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, Spacing.lg)
    }

    private func accountRow(
        label: String,
        logo: some View,
        name: String,
        isPrimary: Bool,
        mask: String?,
        balance: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            Text(label)
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            HStack(spacing: Spacing.lg) {

                logo
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: Spacing.xs) {

                    HStack(spacing: Spacing.sm) {
                        Text(name)
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)

                        if isPrimary {
                            Text("PRIMARY")
                                .textStyle(Typography.eyebrow)
                                .foregroundColor(Color.movo.accent)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Capsule().fill(Color.movo.accentTint))
                                .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                        }
                    }

                    if let mask, !mask.isEmpty {
                        Text(mask)
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)
                    }

                    if !balance.isEmpty {
                        Text(balance)
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Logo tiles

    @ViewBuilder
    private var bankLogoTile: some View {
        if let logo = account?.logoImage {
            Image(uiImage: logo)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        } else {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.movo.accentTint)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                )
                .overlay(
                    Text(initials)
                        .textStyle(Typography.cardTitle)
                        .foregroundColor(Color.movo.accent)
                )
        }
    }

    private var movoLogoTile: some View {
        RoundedRectangle(cornerRadius: Radius.xl)
            .fill(Color.movo.elevatedHigh)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
            .overlay(
                MovoMVSymbol()
                    .frame(width: 26, height: 26)
            )
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {

            Button {
                amountFocused = false
                showConfirmSheet = true
            } label: {
                Text("Transfer")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(!isDoneEnabled)
            .opacity(isDoneEnabled ? 1 : 0.5)

            Button {
                NotificationCenter.default.post(name: .returnToDashboard, object: nil)
            } label: {
                Text("Skip for now")
                    .textStyle(Typography.button)
                    .foregroundColor(Color.movo.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
    }

    /// Runs the ACH deposit (external bank → MOVO) using the entered amount, then
    /// surfaces the shared success screen. Reuses ACHViewModel.initiateTransfer —
    /// the same call FundAccountView makes — so no business logic is duplicated.
    private func submitDeposit() {
        // The deposit only needs the linked bank's achAccountId; the MOVO primary
        // is for display only. Works with or without an injected container.
        guard let account else { return }
        showConfirmSheet = false
        isSubmitting = true

        let fromName = bankName
        let fromMask = bankMask
        let toName = movoName
        let toMask = movoMask
        let enteredAmount = amountValue

        transferTask = Task {
            let vm = container?.makeACHViewModel()
                ?? ACHViewModel(network: NetworkService.shared, alertManager: AlertManager.shared)
            let request = ACHRequest(
                amount: Int(amountText) ?? 0,
                achAccountId: account.achAccountId,
                userAction: "SUBMITS-ACH-DEPOSIT"
            )
            let success = await vm.initiateTransfer(request: request)

            guard !Task.isCancelled else { return }
            isSubmitting = false

            if success {
                successData = SuccessConfirmation(
                    channel: .external,
                    amount: enteredAmount,
                    fromAccountName: fromName,
                    fromAccountMask: fromMask ?? "—",
                    toAccountName: toName,
                    toAccountMask: toMask,
                    arrivesText: "1–3 business days",
                    dateText: Date.now.formatted(date: .long, time: .shortened),
                    referenceCode: "MV-\(String(UUID().uuidString.prefix(8)))"
                )
            }
        }
    }
}

#Preview {
    BankLinkedSuccessScreen()
}

// MARK: - Primary card → SavingsAccountInfo

private extension SavingsAccountInfo {
    /// Builds a display-oriented MOVO primary from the primary VCard
    /// (`VCardAPI.getVCardsPrimary`) — used for the "To" row's name, masked
    /// number and available balance. File-private so it does not collide with
    /// the identical helper in FundAccountView.
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
