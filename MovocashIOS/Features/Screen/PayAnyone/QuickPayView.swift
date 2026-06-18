//
//  QuickPayView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/06/26.
//

import SwiftUI
import Combine

struct QuickPayView: View {

    let primaryLinkedCard: VCardListResponse?
    /// Funding/other cards forwarded to the transfer screen by the payee flow.
    let cards: [VCardListResponse]
    /// Sheet header title (API-driven from the dashboard PAYANYONE section).
    let title: String

    private let container: AppContainer

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.securedDismiss) private var securedDismiss
    @FocusState private var amountFocused: Bool

    @StateObject private var transVM: TransactionViewModel
    @StateObject private var achVM: PlaidAchViewModel
    @ObservedObject private var primaryCardStore: PrimaryCardStore

    @State private var nickname: String = ""
    @State private var phoneNo: String = ""
    @State private var amountText: String = "0"
    @State private var descriptionText: String = ""
    @State private var sendTask: Task<Void, Never>?
    /// Last sanitized number we ran check-intent for, so we don't refire on every keystroke.
    @State private var lastCheckedPhone: String = ""
    /// Drives presentation of the native `CNContactPickerViewController`.
    @State private var showSystemPicker = false
    /// True between tapping "Use phone contact" and the picker finishing presenting —
    /// shows a loader during the picker's (out-of-process) launch delay.
    @State private var isOpeningPicker = false
    /// Drives the Continue/Cancel confirmation popup shown after check-intent succeeds.
    @State private var showConfirm = false
    /// True while the Pay-tap check-intent runs — blocks the screen with a spinner.
    @State private var isChecking = false
    /// Set when Continue is tapped so the send fires in the popup's `onDismiss`
    /// (after the popup cover finishes dismissing, before presenting the success cover).
    @State private var pendingSend = false

    /// Called when the user finishes on the success screen ("Let's MOVO"), so the
    /// Dashboard can refresh on return.
    var onSuccess: () -> Void = {}

    init(container: AppContainer,
         primaryLinkedCard: VCardListResponse? = nil,
         cards: [VCardListResponse] = [],
         title: String = "Quick Pay",
         onSuccess: @escaping () -> Void = {}) {
        self.container = container
        self.primaryLinkedCard = primaryLinkedCard
        self.cards = cards
        self.title = title
        self.onSuccess = onSuccess
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _primaryCardStore = ObservedObject(wrappedValue: container.primaryCardStore)
    }

    /// The card to use: shared store first, falling back to the passed-in prop.
    private var effectivePrimary: VCardListResponse? { primaryCardStore.card ?? primaryLinkedCard }

    private var amount: Double { Double(amountText) ?? 0 }

    private var isFormValid: Bool {
        PhoneNumberValidator.sanitize(phoneNo).count >= 10
            && amount > 0
            && availableBalanceDouble > 0
    }

    // MARK: - Balance helpers

    private var accountBalance: Decimal {
        Decimal(effectivePrimary?.savingsAccountAvailableBalance
                ?? effectivePrimary?.savingsAccountBalance ?? 0)
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
                    title: title,
                    subtitle: "Send to spend",
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
                        .padding(.top, Spacing.lg)
                        
                        recipientSection
                        
                        NoteCard(text: $descriptionText)
                            .padding(.top, Spacing.sm)

                        // Divider + button read as one unit: tight md gap between them,
                        // while the group keeps the section's xl rhythm below NoteCard.
                        VStack(spacing: Spacing.md) {
                            LabeledDivider(text: "OR PICK FROM")
                            UsePhoneContactButton {
                                amountFocused = false
                                UIApplication.shared.dismissKeyboard()
                                isOpeningPicker = true
                                showSystemPicker = true
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
                .scrollDismissesKeyboard(.immediately)

                PayActionButton(amount: amount, isEnabled: isFormValid) {
                    amountFocused = false
                    UIApplication.shared.dismissKeyboard()
                    // Self-contained flow: check-intent → confirm popup → send directly
                    // from this screen. QuickTransferView is intentionally not presented.
                    Task { await prepareAndConfirm() }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.sm)
            }
            // The send (achVM) and the Pay-tap check-intent both show the spinner. The
            // keystroke check-intent on transVM still runs silently (see runCheckIntentIfReady).
            .blur(radius: (achVM.state == .loading || isChecking || isOpeningPicker) ? 3 : 0)

            if achVM.state == .loading || isChecking || isOpeningPicker {
                Color.black.opacity(0.5).ignoresSafeArea()
                SpinnerView()
            }

            // On transfer success the confirmation screen slides up as a full-screen
            // layer over this view — presented FIRST, with the Quick Pay form hidden
            // behind it. "Let's MOVO" dismisses the whole Quick Pay cover in one
            // transition, revealing the Dashboard with no flicker.
            if let success = achVM.peerTransferSuccess {
                SuccessConfirmationView(
                    viewModel: SuccessConfirmationViewModel(success: success) {
                        onSuccess()
                        (securedDismiss ?? dismiss)()
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: achVM.peerTransferSuccess?.id)
        // Hosts the native contact picker; presents when `showSystemPicker` flips true.
        .background {
            PhoneContactPicker(
                isPresented: $showSystemPicker,
                onPresented: { isOpeningPicker = false }
            ) { name, phone in
                applyPickedContact(name: name, phone: phone)
            }
        }
        .onChange(of: amountFocused) { focused in
            if focused && amountText == "0" { amountText = "" }
            if !focused && amountText.isEmpty { amountText = "0" }
        }
        // Confirmation popup with the recipient's check-intent message/disclaimer.
        // On Continue we arm `pendingSend` and dismiss; the send fires in `onDismiss`.
        .contactEnrollPopup(
            isPresented: $showConfirm,
            title: transVM.checkIntentResult?.message ?? "",
            message: transVM.checkIntentResult?.disclaimer ?? "",
            avatarInitial: nickname.first.map { String($0).uppercased() } ?? "",
            onDismiss: { if pendingSend { pendingSend = false; Task { await sendMoney() } } },
            onContinue: { pendingSend = true; setConfirm(false) },
            onCancel: { pendingSend = false; setConfirm(false) }
        )
        .globalAlert()
        .onSessionExpired {
            // Cancel the in-flight send only; RootView navigates to login.
            sendTask?.cancel()
            sendTask = nil
        }
    }

    // MARK: - Recipient

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            Text("RECIPIENT")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            VStack(spacing: Spacing.lg) {
                CustomTextField(text: $nickname)
                CustomPhoneField(phoneNumber: $phoneNo)
            }
        }
    }

    // MARK: - Use phone contact

    /// Fills the recipient fields from a contact picked in the native system picker.
    /// `sanitize` yields the 10-digit national number; `CustomPhoneField` re-formats it.
    private func applyPickedContact(name: String, phone: String) {
        nickname = name
        phoneNo = PhoneNumberValidator.sanitize(phone)
    }

    /// Pay tapped: run a fresh check-intent for the entered number, then show the
    /// confirmation popup. On check-intent failure only the error toast shows (no popup),
    /// matching the shared payee flow. The actual send happens after Continue (see
    /// `.contactEnrollPopup`'s `onDismiss`).
    private func prepareAndConfirm() async {
        let sanitized = PhoneNumberValidator.sanitize(phoneNo)
        let normalized = PhoneNumberValidator.normalize(sanitized)
        isChecking = true
        await transVM.checkIntent(phoneNumber: normalized)
        isChecking = false
        guard transVM.checkIntentResult != nil else { return }
        lastCheckedPhone = sanitized
        setConfirm(true)
    }

    /// Toggles the confirmation cover without the fullScreenCover's default bottom
    /// slide, so only `CustomContactEnrollView`'s center scale/fade plays — the popup
    /// expands from / contracts to center on present and dismiss/cancel.
    private func setConfirm(_ visible: Bool) {
        // Qualify SwiftUI.Transaction — the app also defines a `Transaction` model.
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { showConfirm = visible }
    }

    private func sendMoney() async {
        guard let fromCard = effectivePrimary else {
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
