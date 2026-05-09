//
//  QuickTransferView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct QuickTransferView: View {

    let contact: ContactRecord
    let accounts: [SavingsAccountInfo]

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var transVM: TransactionViewModel
    @FocusState private var amountFocused: Bool

    @State private var amountText = "0"
    @State private var descriptionText = ""
    @State private var selectedAccount: SavingsAccountInfo?
    @State private var showConfirmSheet = false
    @State private var successData: SuccessConfirmation?

    init(contact: ContactRecord, container: AppContainer, accounts: [SavingsAccountInfo]) {
        self.contact = contact
        self.accounts = accounts
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        let primary = accounts.first(where: { $0.isPrimary }) ?? accounts.first
        _selectedAccount = State(wrappedValue: primary)
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool { amount > 0 && selectedAccount != nil }

    // MARK: - Amount display helpers

    private var availableBalanceDisplay: String {
        selectedAccount.map { "$\($0.availableBalance.toCurrencyString())" } ?? "$0.00"
    }

    private var availableBalanceDouble: Double {
        guard let account = selectedAccount else { return 0 }
        return NSDecimalNumber(decimal: account.availableBalance).doubleValue
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        recipientSection
                        amountSection
                        noteCard
                        accountCard
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }

            sendButton
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 36)
        }
        .background(Color.movo.background)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onChange(of: amountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        .globalAlert()
        .sheet(isPresented: $showConfirmSheet) {
            ConfirmationBottomSheet(
                channel: .peer,
                amount: amountText,
                fromName: selectedAccount.map { $0.nickname ?? $0.clientName } ?? "—",
                fromMask: selectedAccount?.maskedAccountNumber,
                toName: contact.nickname ?? contact.phoneNumber ?? "—",
                toMask: contact.phoneNumber.map { "••\($0.suffix(4))" },
                isLoading: transVM.state == .loading,
                onCancel: { showConfirmSheet = false },
                onConfirm: { Task { await sendMoney() } }
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
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.movo.elevated, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Send money")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.movo.elevated, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg - 2)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Recipient

    private var recipientSection: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(Color.movo.elevated)
                Circle().strokeBorder(Color.movo.accent, lineWidth: 1.5)
                Text(contact.initials)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 72, height: 72)
            .padding(.bottom, Spacing.xs)
            
            HStack(spacing: 8) {
                Text("TO")
                    .font(Typography.eyebrow.font)
                    .tracking(1.2)
                    .foregroundColor(Color.movo.textTertiary)

                Text(contact.nickname ?? "")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.movo.textPrimary)
            }

            HStack(spacing: 8) {
                Text(contact.phoneNumber ?? "")
                    .font(Typography.caption.font)
                    .foregroundColor(Color.movo.textTertiary)

                if contact.isAdded {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.movo.accent)
                            .frame(width: 5, height: 5)
                        Text("ON MOVO")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(Color.movo.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.movo.accentTint)
                            .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: Spacing.md) {
            amountDisplay

            Text("\(availableBalanceDisplay) available")
                .font(Typography.caption.font)
                .foregroundColor(Color.movo.textTertiary)

            quickChips
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)

            let parts = amountText.split(separator: ".")
            Text(parts.first.map(String.init) ?? "0")
                .font(.system(size: 72, weight: .bold).monospacedDigit())
                .foregroundColor(Color.movo.textPrimary)

            Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                .font(.system(size: 32, weight: .semibold).monospacedDigit())
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)
        }
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = true }
        .overlay(
            TextField("", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .opacity(0)
        )
    }

    private let presets: [(String, Double?)] = [
        ("$10", 10), ("$25", 25), ("$50", 50), ("$100", 100)
    ]

    private var quickChips: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(presets, id: \.0) { label, value in
                let selected = isPresetSelected(value)
                Button { applyPreset(value) } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selected ? Color.movo.accent : Color.movo.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selected ? Color.movo.accentTint : Color.movo.elevated)
                                .overlay(
                                    Capsule().strokeBorder(
                                        selected ? Color.movo.accentBorder : Color.clear,
                                        lineWidth: Stroke.hairline
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isPresetSelected(_ value: Double?) -> Bool {
        guard amount > 0 else { return false }
        if let v = value { return amount == v }
        return amount == availableBalanceDouble && !amountText.isEmpty
    }

    private func applyPreset(_ value: Double?) {
        amountFocused = false
        if let v = value {
            amountText = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
        } else {
            guard let account = selectedAccount else { return }
            let raw = NSDecimalNumber(decimal: account.availableBalance).stringValue
            amountText = raw
        }
    }

    // MARK: - Note Card

    private var noteCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.movo.textDisabled)

            TextField("", text: $descriptionText,
                      prompt: Text("What's it for? (optional)")
                          .foregroundColor(Color.movo.textDisabled))
                .font(Typography.body.font)
                .foregroundColor(Color.movo.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.movo.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline)
                )
        )
    }

    // MARK: - Account Card

    private var accountCard: some View {
        Group {
            if accounts.isEmpty {
                HStack {
                    Text("No accounts available")
                        .font(Typography.caption.font)
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                }
                .padding(Spacing.lg)
                .background(cardBackground)
            } else {
                Menu {
                    ForEach(accounts) { account in
                        Button { selectedAccount = account } label: {
                            Text("\(account.nickname ?? account.clientName)  \(account.maskedAccountNumber)")
                        }
                    }
                } label: {
                    accountCardContent
                }
            }
        }
    }

    private var accountCardContent: some View {
        HStack(spacing: 14) {
            // Movo logo square
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.elevatedHigh)
                Text("M")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.movo.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                if let account = selectedAccount {
                    Text("FROM  ·  \(account.maskedAccountNumber)")
                        .font(Typography.captionSmall.font)
                        .foregroundColor(Color.movo.textTertiary)
                    Text(account.nickname ?? account.clientName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                } else {
                    Text("FROM")
                        .font(Typography.captionSmall.font)
                        .foregroundColor(Color.movo.textTertiary)
                    Text("Select account")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.movo.textDisabled)
                }
            }

            Spacer()

            if let account = selectedAccount {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(account.availableBalance.toCurrencyString())")
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundColor(Color.movo.textPrimary)
                    Text("available")
                        .font(Typography.captionSmall.font)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.movo.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline)
            )
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            UIApplication.shared.dismissKeyboard()
            amountFocused = false
            showReview()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                Text(amount > 0 ? "Send $\(String(format: "%.2f", amount))" : "Send")
                    .font(.system(size: 16, weight: .semibold))
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
        guard let fromAccount = selectedAccount else { return }

        let rawPhone = contact.phoneNumber ?? ""
        let withCountry = rawPhone.hasPrefix("+1") ? rawPhone : "+1\(rawPhone.filter(\.isNumber))"
        let sanitized = PhoneNumberValidator.sanitize(withCountry)
        let normalizedPhone = PhoneNumberValidator.normalize(sanitized)

        let request = TransactionRequest.Internal(
            description: descriptionText,
            amount: amount,
            toAccountId: 0,
            toClientId: 0,
            fromAccountId: fromAccount.id,
            phoneNumber: normalizedPhone,
            userAction: "Internal-Transfer",
            nickname: contact.nickname ?? ""
        )
        guard await transVM.submitInternalTransfer(request: request) else { return }

        showConfirmSheet = false
        let dateText = Date.now.formatted(date: .long, time: .shortened)
        successData = SuccessConfirmation(
            channel: .peer,
            amount: Decimal(string: amountText) ?? 0,
            fromAccountName: fromAccount.nickname ?? fromAccount.clientName,
            fromAccountMask: fromAccount.maskedAccountNumber,
            toAccountName: contact.nickname ?? contact.phoneNumber ?? "",
            toAccountMask: nil,
            arrivesText: "Instantly",
            dateText: dateText,
            referenceCode: "MV-\(Date.now.formatted(.iso8601).prefix(10).replacingOccurrences(of: "-", with: ""))-\(String(UUID().uuidString.prefix(4)))"
        )
    }
}
