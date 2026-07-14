//
//  ShareInviteSheet.swift
//  MovocashIOS
//
//  Created by Vinu on 24/06/26.
//

import SwiftUI
import ContactsUI
import MessageUI

struct ShareInviteSheet: View {
    let onClose: () -> Void
    let onInviteSent: (String?) -> Void
    let inviterName: String

    /// The dashboard INVITE-A-FRIEND section — drives the header copy and invitee list.
    let invite: DashboardInviteAFriend?

    private var sheetTitle: String { invite?.title ?? "Invite someone to Movo" }
    private var sheetSubtitle: String { invite?.description ?? "Send a join code to a contact" }

    @StateObject private var transVM: TransactionViewModel
    @StateObject private var contactVM: ContactViewModel
    @State private var phoneNo: String = ""
    @State private var nickname: String = ""
    @State private var isPhoneFocused = false
    @State private var showSystemPicker = false
    @State private var showConfirm = false
    @State private var pendingInvite = false
    @State private var showMessageComposer = false
    @State private var isLoadingInvitees = false

    private static let appStoreURL = "https://apps.apple.com/app/id1538828856"

    private var inviteSMSBody: String {
        let inviter = inviterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let opener = inviter.isEmpty
            ? "You've been invited to become the next Movoian!"
            : "\(inviter) invited you to become the next Movoian!"
        return """
        \(opener)

        Download the app:
        \(Self.appStoreURL)

        Android support coming soon.

        Let's MOVO!
        """
    }
    
    private var recipientE164: String {
        "+1" + String(phoneNo.filter(\.isNumber).suffix(10))
    }

    init(container: AppContainer,
         inviterName: String = "",
         invite: DashboardInviteAFriend? = nil,
         onClose: @escaping () -> Void,
         onInviteSent: @escaping (String?) -> Void) {
        self.inviterName = inviterName
        self.invite = invite
        self.onClose = onClose
        self.onInviteSent = onInviteSent
        _transVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
    }

    private var isNumberValid: Bool {
        phoneNo.filter(\.isNumber).count == 10
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomSheetHeader(
                title: sheetTitle,
                subtitle: "", //sheetSubtitle
                systemImage: "person.badge.plus",
                iconTint: Color.movo.accent,
                iconBackground: Color.movo.accentTint,
                horizontalPadding: Spacing.xl,
                closeAction: onClose
            )

            VStack(spacing: Spacing.lg) {

                UsePhoneContactButton {
                    isPhoneFocused = false   // dismiss keyboard before opening the picker
                    SpinnerView.showFullScreen()
                    showSystemPicker = true
                }
                
                LabeledDivider(text: "OR ENTER PHONE NUMBER")
                
                CustomPhoneField(phoneNumber: $phoneNo, isFocused: $isPhoneFocused)

                CustomTextField(text: $nickname, placeholder: "Nickname (optional)")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)

            // Only shown once the invited list has actually loaded (non-empty).
            if !contactVM.referralInvitees.isEmpty {
                invitedListSection
            }
            Spacer()
            Button {
                sendInviteTapped()
            } label: {
                Text("CONTINUE")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(!isNumberValid)
            .opacity(isNumberValid ? 1.0 : 0.4)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.movo.cardSurface.ignoresSafeArea())
        // Hosts the native contact picker; presents when `showSystemPicker` flips true.
        .background {
            PhoneContactPicker(
                isPresented: $showSystemPicker,
                onPresented: { SpinnerView.hideFullScreen() }
            ) { name, phone in
                phoneNo = Self.normalizedUSDigits(from: phone)
                nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Invite-mode enroll popup. exists == true → number is already a Movo user,
        // so the "Send Invite" button is hidden and only Cancel shows.
        .contactEnrollPopup(
            isPresented: $showConfirm,
            title: transVM.checkIntentResult?.message ?? "",
            message: transVM.checkIntentResult?.disclaimer ?? "",
            avatarInitial: "",
            continueTitle: "SEND INVITE",
            cancelTitle: "CANCEL",
            showsContinue: !(transVM.checkIntentResult?.exists ?? false),
            onDismiss: {
                // Open the SMS composer only after the popup's cover is fully gone.
                if pendingInvite {
                    pendingInvite = false
                    UIApplication.shared.dismissKeyboard()
                    guard MFMessageComposeViewController.canSendText() else {
                        ToastManager.shared.show(
                            "Text messaging isn't available on this device.",
                            style: .error,
                            position: .bottom
                        )
                        return
                    }
                    showMessageComposer = true
                }
            },
            onContinue: {
                isPhoneFocused = false
                UIApplication.shared.dismissKeyboard()
                pendingInvite = true
                showConfirm = false
            },
            onCancel: { pendingInvite = false; showConfirm = false }
        )
        // Hosts the native Messages composer, pre-filled with the deeplink + code.
        .background {
            MessageComposeView(
                isPresented: $showMessageComposer,
                recipients: [recipientE164],
                body: inviteSMSBody,
                onFinish: { result in
                    guard result == .sent else { return }
                    // Notify the skinny processor that the invite was sent, then
                    // surface the server's success message via onInviteSent.
                    let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                    SpinnerView.showFullScreen()
                    Task {
                        let message = await contactVM.inviteUser(
                            phone: recipientE164,
                            nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
                        )
                        SpinnerView.hideFullScreen()
                        onInviteSent(message)
                    }
                }
            )
        }
        .onAppear {
            loadInvitees()
        }
        // Safety: never leave the full-screen spinner up if the sheet goes away.
        .onDisappear { SpinnerView.hideFullScreen() }
    }

    /// "SEND INVITE" — dismisses the keyboard first, then runs check-intent; on
    /// success shows the enroll popup whose buttons adapt to whether the number
    /// already belongs to a Movo user.
    private func sendInviteTapped() {
        isPhoneFocused = false
        UIApplication.shared.dismissKeyboard()
        let normalized = PhoneNumberValidator.normalize(PhoneNumberValidator.sanitize(phoneNo))
        SpinnerView.showFullScreen()
        Task {
            // Let the keyboard finish resigning before the call / popup appears.
            try? await Task.sleep(nanoseconds: 150_000_000)
            await transVM.checkIntent(phoneNumber: normalized, userAction: "CHECK-REFERRAL-INTENT")
            SpinnerView.hideFullScreen()
            guard transVM.checkIntentResult != nil else { return }
            showConfirm = true
        }
    }

    private static func normalizedUSDigits(from raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        let national = (digits.count == 11 && digits.hasPrefix("1"))
            ? String(digits.dropFirst())
            : digits
        return String(national.prefix(10))
    }

    // MARK: - Invited list ("See all invitees")

    /// Fetches the already-invited list via GET-REFERRAL-LIST.
    private func loadInvitees() {
        isLoadingInvitees = true
        Task {
            await contactVM.loadReferralInvitees()
            isLoadingInvitees = false
        }
    }

    @ViewBuilder
    private var invitedListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LabeledDivider(text: "INVITED")
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(contactVM.referralInvitees.enumerated()), id: \.offset) { _, invitee in
                        inviteeRow(invitee)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
    }

    private func inviteeRow(_ invitee: ReferralInvitee) -> some View {
        let name = invitee.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !(name?.isEmpty ?? true)
        let phone = displayPhone(invitee.inviteePhone)
        let joined = invitee.joined ?? false
        return HStack(spacing: Spacing.md) {
            // Avatar — accent-tinted with a ring once the invitee has joined,
            // neutral while still pending.
            ZStack {
                Circle().fill(joined ? Color.movo.accentTint : Color.movo.elevatedHigh)
                if hasName, let initial = name?.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(joined ? Color.movo.accent : Color.movo.textPrimary)
                } else {
                    MovoMVSymbol()
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 44, height: 44)
            .overlay(
                Circle().strokeBorder(
                    joined ? Color.movo.accent.opacity(0.5) : Color.clear,
                    lineWidth: Stroke.thin
                )
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(hasName ? (name ?? phone) : phone)
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                if hasName {
                    Text(phone)
                        .textStyle(Typography.subtitle)
                        .foregroundColor(Color.movo.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            // Status chip — icon + label so state reads at a glance.
            HStack(spacing: Spacing.xxs) {
                Image(systemName: joined ? "checkmark.seal.fill" : "paperplane.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(joined ? "JOINED" : "INVITED")
                    .textStyle(Typography.pill)
            }
            .foregroundColor(joined ? Color.movo.accent : Color.movo.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs + 2)
            .background(
                Capsule().fill(joined ? Color.movo.accentTint : Color.movo.elevated)
            )
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.movo.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.25),
                              lineWidth: Stroke.hairline)
        )
    }

    /// Formats an E.164 US number (`+19999666666`) as `(999) 966-6666`; falls back
    /// to the raw value for anything unexpected.
    private func displayPhone(_ raw: String?) -> String {
        guard let raw else { return "" }
        let digits = raw.filter(\.isNumber)
        let national = (digits.count == 11 && digits.hasPrefix("1")) ? String(digits.dropFirst()) : digits
        guard national.count == 10 else { return raw }
        let area = national.prefix(3)
        let mid = national.dropFirst(3).prefix(3)
        let last = national.suffix(4)
        return "(\(area)) \(mid)-\(last)"
    }
}

// MARK: - Messages composer

/// Wraps `MFMessageComposeViewController` so the native SMS composer can be
/// presented (pre-filled with recipient + body) from SwiftUI. Presented from an
/// otherwise-empty host controller so its self-dismissal stays in sync with
/// `isPresented`. Mirrors the `PhoneContactPicker` hosting pattern.
struct MessageComposeView: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    let recipients: [String]
    let body: String
    /// Fired after the composer dismisses, with the result (sent / cancelled /
    /// failed). `.failed` is also used when SMS isn't available (e.g. Simulator).
    var onFinish: ((MessageComposeResult) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        // Keep the coordinator's callbacks/bindings fresh across re-renders.
        context.coordinator.parent = self

        guard isPresented else {
            // Reset on the falling edge so the next request can present again.
            context.coordinator.didPresent = false
            return
        }

        // Present exactly once per rising edge of `isPresented` — guards against
        // SwiftUI invoking updateUIViewController multiple times (double send).
        guard !context.coordinator.didPresent else { return }
        context.coordinator.didPresent = true

        // No SMS capability (e.g. Simulator / no SIM) — bail cleanly.
        guard MFMessageComposeViewController.canSendText() else {
            DispatchQueue.main.async {
                isPresented = false
                onFinish?(.failed)
            }
            return
        }

        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        composer.recipients = recipients
        composer.body = body
        DispatchQueue.main.async { host.present(composer, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposeView
        /// True while a composer has been presented for the current `isPresented`
        /// rising edge; reset when `isPresented` returns to false.
        var didPresent = false

        init(_ parent: MessageComposeView) { self.parent = parent }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                // Setting isPresented false resets `didPresent` via updateUIViewController.
                self.parent.isPresented = false
                self.parent.onFinish?(result)
            }
        }
    }
}
