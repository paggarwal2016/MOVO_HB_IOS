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
    @State private var showAccountSheet: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var successData: SuccessConfirmation?
    @State private var transferTask: Task<Void, Never>?
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
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            transferTask?.cancel()
            transferTask = nil
            isSubmitting = false
            showConfirmSheet = false
            showAccountSheet = false
            dismiss()
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
                    showConfirmSheet = false
                    isSubmitting = true
                    transferTask = Task {
                        let request = ACHRequest(
                            amount: Int(amount) ?? 0,
                            achAccountId: account.achAccountId,
                            userAction: "SUBMITS-ACH-DEPOSIT"
                        )
                        let success = await vm.initiateTransfer(request: request)
                        guard !Task.isCancelled else { return }
                        isSubmitting = false
                        if success {
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
                } else if sortedAccounts.isEmpty {
                    Button {
                        Task {
                            await achVM.startPlaidLink()
                            if achVM.linkedAccount != nil {
                                await vm.fetchAccounts()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.movo.accentTint)
                                    .frame(width: 46, height: 46)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.movo.accent)
                            }
                            Text(achVM.state == .loading ? "Connecting..." : "Connect bank account")
                                .font(Typography.body.font)
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
                    .disabled(achVM.state == .loading)
                } else {
                    Button {
                        isAmountFocused = false
                        if sortedAccounts.count > 1 { showAccountSheet = true }
                    } label: {
                        accountRow(
                            avatar: bankInitialsAvatar,
                            title: selectedAccount?.accountName ?? "—",
                            subtitle: "\(selectedAccount?.formattedBalance ?? "") · ••\((selectedAccount?.accountNumber ?? "").suffix(4))",
                            showChevron: sortedAccounts.count > 1
                        )
                    }
                    .buttonStyle(.plain)
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
            isAmountFocused = false
            UIApplication.shared.dismissKeyboard()
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

    // MARK: - Amount Entry (number pad)

    private func showAmountPad() {
        isAmountFocused = true
    }

}

// MARK: - Bank Account Picker Sheet

private struct BankAccountPickerSheet: View {
    let accounts: [ACHAccount]
    @Binding var selected: ACHAccount?
    @SwiftUI.Environment(\.dismiss) private var dismiss

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
                                        Text(account.accountName.prefix(2).uppercased())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.movo.textPrimary)
                                    }
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.accountName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.movo.textPrimary)
                                    Text("••\(account.accountNumber.suffix(4)) · \(account.formattedBalance)")
                                        .font(.system(size: 13, weight: .regular))
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
            .navigationTitle("Select Account")
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
