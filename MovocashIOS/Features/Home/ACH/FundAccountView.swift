//
//  FundAccountView.swift
//  MovocashIOS
//
//  Created by Vinu on 09/04/26.
//

import SwiftUI

struct FundAccountView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject private var vm: ACHViewModel
    @StateObject private var achVM: PlaidAchViewModel

    let primaryAccount: SavingsAccountInfo
    let onConnectBank: () -> Void

    init(container: AppContainer, vm: ACHViewModel, primaryAccount: SavingsAccountInfo, onConnectBank: @escaping () -> Void) {
        self.vm = vm
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        self.primaryAccount = primaryAccount
        self.onConnectBank = onConnectBank
    }

    @State private var selectedAccount: ACHAccount?
    @State private var amount: String = "0"
    @State private var showConfirmSheet: Bool = false
    @State private var isFromExpanded: Bool = false
    @State private var successData: SuccessConfirmation?
    @FocusState private var isAmountFocused: Bool

    private var enteredAmount: Decimal { Decimal(string: amount) ?? 0 }

    private var amountExceedsBalance: Bool {
        guard let account = selectedAccount else { return false }
        return enteredAmount > account.plaidAccountBalance
    }

    private var isFormValid: Bool {
        selectedAccount != nil && enteredAmount > 0 && !amountExceedsBalance
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
            }

        }
        .blur(radius: showConfirmSheet ? 6 : 0)
        .background(Color.movo.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedAccount == nil {
                selectedAccount = vm.accounts.first(where: { $0.isDefault }) ?? vm.accounts.first
            }
        }
        .onChange(of: vm.accounts) { accounts in
            if selectedAccount == nil {
                selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            }
        }
        .onChange(of: isAmountFocused) { focused in
            if focused && amount == "0" { amount = "" }
            if !focused && amount.isEmpty { amount = "0" }
        }
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .external,
                amount: amount,
                fromName: selectedAccount?.accountName ?? "—",
                fromMask: selectedAccount.map { "••\($0.accountNumber.suffix(4))" },
                toName: primaryAccount.displayName,
                toMask: primaryAccount.maskedAccountNumber,
                isLoading: vm.state == .loading,
                onCancel: { showConfirmSheet = false },
                onConfirm: {
                    guard let account = selectedAccount else { return }
                    Task {
                        let request = ACHRequest(
                            amount: Int(amount) ?? 0,
                            achAccountId: account.achAccountId,
                            userAction: "SUBMITS-ACH-DEPOSIT"
                        )
                        let success = await vm.initiateTransfer(request: request)
                        if success {
                            showConfirmSheet = false
                            let dateText = Date.now.formatted(date: .long, time: .shortened)
                            successData = SuccessConfirmation(
                                channel: .external,
                                amount: Decimal(string: amount) ?? 0,
                                fromAccountName: account.accountName,
                                fromAccountMask: "••\(account.accountNumber.suffix(4))",
                                toAccountName: primaryAccount.displayName,
                                toAccountMask: primaryAccount.maskedAccountNumber,
                                arrivesText: "1–3 business days",
                                dateText: dateText,
                                referenceCode: "MV-\(Date.now.formatted(.iso8601).prefix(10).replacingOccurrences(of: "-", with: ""))-\(String(UUID().uuidString.prefix(4)))"
                            )
                        }
                    }
                }
            )
            .padding(.top, 30)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .fullScreenCover(item: $successData) { data in
            SuccessConfirmationView(
                viewModel: SuccessConfirmationViewModel(success: data) {
                    successData = nil
                    dismiss()
                }
            )
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Color.clear.frame(width: 32, height: 32)
            Spacer()
            Text("Funds Transfer")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            CircularNavButton(systemName: "xmark") { dismiss() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)

            let parts = amount.split(separator: ".")
            Text(parts.first.map(String.init) ?? "0")
                .font(.system(size: 72, weight: .bold).monospacedDigit())
                .foregroundColor(Color.movo.textPrimary)

            Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                .font(.system(size: 32, weight: .semibold).monospacedDigit())
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

    // MARK: - Account Radio List

    private var accountRadioList: some View {
        VStack(spacing: 0) {
            ForEach(sortedAccounts, id: \.achAccountId) { account in
                Rectangle()
                    .fill(Color.movo.border)
                    .frame(height: Stroke.hairline)
                    .padding(.horizontal, Spacing.lg)
                Button {
                    selectedAccount = account
                    withAnimation(.easeInOut(duration: 0.2)) { isFromExpanded = false }
                } label: {
                    bankAccountRadioRow(account)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Transfer Panel (From / To rows)

    private var transferPanel: some View {
        VStack(spacing: 0) {
            // FROM — bank account(s)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("From")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)

                if vm.state == .loading && vm.accounts.isEmpty {
                    HStack {
                        ProgressView().tint(Color.movo.textSecondary)
                        Text("Loading accounts…")
                            .font(.system(size: 13))
                            .foregroundColor(Color.movo.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                } else if vm.accounts.isEmpty {
                    Text("No bank accounts linked")
                        .font(.system(size: 14))
                        .foregroundColor(Color.movo.textTertiary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                } else if vm.accounts.count == 1, let account = vm.accounts.first {
                    accountRow(
                        avatar: bankInitialsAvatar,
                        title: account.accountName,
                        subtitle: "\(account.formattedBalance) · ••\(account.accountNumber.suffix(4))",
                        showChevron: false
                    )
                } else {
                    // Collapsed header — shows selected account + expand toggle
                    let displayed = selectedAccount ?? sortedAccounts.first
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isFromExpanded.toggle() }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            bankInitialsAvatar
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayed?.accountName ?? "")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color.movo.textPrimary)
                                Text("\(displayed?.formattedBalance ?? "") · ••\((displayed?.accountNumber ?? "").suffix(4))")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.movo.textTertiary)
                            }
                            Spacer()
                            Image(systemName: isFromExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.movo.textDisabled)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)

                    // Expanded radio list — scrollable when 3 or more accounts
                    if isFromExpanded {
                        if sortedAccounts.count >= 3 {
                            ScrollView(.vertical, showsIndicators: false) {
                                accountRadioList
                            }
                            .frame(maxHeight: 180)
                        } else {
                            accountRadioList
                        }
                    }
                }
            }

            // Swap divider
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

            // TO — Movo primary
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("To")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)

                accountRow(
                    avatar: movoAvatar,
                    title: primaryAccount.displayName,
                    subtitle: "\(primaryAccount.formattedBalance) · \(primaryAccount.maskedAccountNumber)",
                    showChevron: false
                )
            }
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
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Account Row

    private func accountRow(
        avatar: some View,
        title: String,
        subtitle: String,
        showChevron: Bool
    ) -> some View {
        HStack(spacing: Spacing.md) {
            AnyView(avatar)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
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
                Text(selectedAccount?.accountName.prefix(2).uppercased() ?? "••")
                    .font(.system(size: 16, weight: .semibold))
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
            MLogo()
                .frame(width: 28, height: 28)
        }
    }

    // MARK: - Transfer Button

    private var transferButton: some View {
        Button {
            guard isFormValid else { return }
            showConfirmSheet = true
        } label: {
            Group {
                if vm.state == .loading {
                    ProgressView().tint(Color.movo.background)
                } else {
                    Text("Transfer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.movo.background)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(isFormValid ? Color.movo.accent : Color.movo.accent.opacity(0.8))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid)
    }

    // MARK: - Bank Account Radio Row

    private func bankAccountRadioRow(_ account: ACHAccount) -> some View {
        let isSelected = selectedAccount?.achAccountId == account.achAccountId
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
                if let image = account.logoImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(account.accountName.prefix(2).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.accountName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                Text("••\(account.accountNumber.suffix(4)) · \(account.formattedBalance)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? Color.movo.accent : Color.movo.border,
                        lineWidth: 2
                    )
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color.movo.accent)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Amount Entry (number pad)

    private func showAmountPad() {
        isAmountFocused = true
    }

}
