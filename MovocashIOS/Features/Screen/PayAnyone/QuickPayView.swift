//
//  QuickPayView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/06/26.
//

import SwiftUI
import MobileBankingSDK

struct QuickPayView: View {

    let primaryLinkedCard: VCardListResponse?

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @FocusState private var amountFocused: Bool

    @StateObject private var transVM: TransactionViewModel
    @StateObject private var achVM: PlaidAchViewModel

    @State private var nickname: String = ""
    @State private var phoneNo: String = ""
    @State private var amountText: String = "0"
    @State private var descriptionText: String = ""
    @State private var sendTask: Task<Void, Never>?
    /// Last sanitized number we ran check-intent for, so we don't refire on every keystroke.
    @State private var lastCheckedPhone: String = ""

    var onSuccess: () -> Void = {}

    init(container: AppContainer,
         primaryLinkedCard: VCardListResponse? = nil,
         onSuccess: @escaping () -> Void = {}) {
        self.primaryLinkedCard = primaryLinkedCard
        self.onSuccess = onSuccess
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }

    private var amount: Double { Double(amountText) ?? 0 }

    /// Pay enables on a valid US phone number and a positive amount. Nickname and
    /// note are optional. The funding card / balance are validated at send time so
    /// the button reflects the user's own input rather than data-load state.
    private var isFormValid: Bool {
        PhoneNumberValidator.isValidUSNumber(PhoneNumberValidator.sanitize(phoneNo))
            && amount > 0
    }

    // MARK: - Balance helpers

    private var accountBalance: Decimal {
        Decimal(primaryLinkedCard?.savingsAccountAvailableBalance ?? 0)
    }

    private var availableBalanceDisplay: String {
        "$\(accountBalance.toCurrencyString())"
    }

    private var availableBalanceDouble: Double {
        NSDecimalNumber(decimal: accountBalance).doubleValue
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.movo.background.ignoresSafeArea()

            VStack(spacing: 0) {

                CustomSheetHeader(
                    title: "Quick Pay",
                    subtitle: "Spend money instantly",
                    systemImage: "bolt.fill",
                    iconTint: Color.movo.accent,
                    iconBackground: Color.movo.accentTint,
                    horizontalPadding: Spacing.lg
                ) {
                    dismiss()
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {

                        AmountEntrySection(
                            amountText: $amountText,
                            amountFocused: $amountFocused,
                            availableText: "\(availableBalanceDisplay) available",
                            maxValue: availableBalanceDouble
                        )
                        recipientSection
                        NoteCard(text: $descriptionText)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.xl)
                }
                .scrollDismissesKeyboard(.immediately)

                PayActionButton(amount: amount, isEnabled: isFormValid) {
                    amountFocused = false
                    UIApplication.shared.dismissKeyboard()
                    sendTask = Task { await sendMoney() }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.sm)
            }
            // Only the send (achVM) shows the spinner. The check-intent call on
            // transVM runs silently in the background while the user is still typing.
            .blur(radius: achVM.state == .loading ? 3 : 0)

            if achVM.state == .loading {
                Color.black.opacity(0.5).ignoresSafeArea()
                SpinnerView()
            }
        }
        .onChange(of: amountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        // Run check-intent once the user has entered a complete, valid number so the
        // transfer route (internal vs external) is resolved before they tap Pay.
        .onChange(of: phoneNo) { _ in runCheckIntentIfReady() }
        .globalAlert()
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            sendTask?.cancel()
            sendTask = nil
            (securedDismiss ?? dismiss)()
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
    }

    // MARK: - Recipient

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            Text("RECIPIENT")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            VStack(spacing: Spacing.md) {
                CustomTextField(text: $nickname)
                CustomPhoneField(phoneNumber: $phoneNo)
            }
        }
    }

    // MARK: - Actions

    private func runCheckIntentIfReady() {
        let sanitized = PhoneNumberValidator.sanitize(phoneNo)
        guard PhoneNumberValidator.isValidUSNumber(sanitized),
              sanitized != lastCheckedPhone else { return }
        lastCheckedPhone = sanitized
        let normalized = PhoneNumberValidator.normalize(sanitized)
        Task { await transVM.checkIntent(phoneNumber: normalized) }
    }

    private func sendMoney() async {
        guard let fromCard = primaryLinkedCard else {
            ToastManager.shared.show("No funding account available.", style: .error)
            return
        }
        guard !Task.isCancelled else { return }

        // Block the transfer when there is no spendable balance on the funding card.
        guard availableBalanceDouble > 0 else {
            ToastManager.shared.show("No available balance to send.", style: .error)
            return
        }

        let sanitized = PhoneNumberValidator.sanitize(phoneNo)
        let normalizedPhone = PhoneNumberValidator.normalize(sanitized)

        // checkIntent result drives the transfer route:
        //   exists == true  → recipient is a MOVO user → internal transfer
        //   exists == false / nil → external recipient → external transfer
        let isInternal = transVM.checkIntentResult?.exists ?? false

        await achVM.sendMoneyToContact(
            fromCard: fromCard,
            toName: nickname.isEmpty ? phoneNo : nickname,
            normalizedPhone: normalizedPhone,
            amount: amount,
            amountText: amountText,
            description: descriptionText.isEmpty ? nil : descriptionText,
            isInternal: isInternal
        )
    }
}
