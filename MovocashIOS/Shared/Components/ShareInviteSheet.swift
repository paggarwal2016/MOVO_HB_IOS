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
    let onInviteSent: () -> Void
    let inviterName: String

    /// The dashboard INVITE-A-FRIEND section — drives the header copy and invitee list.
    let invite: DashboardInviteAFriend?

    private var sheetTitle: String { invite?.title ?? "Invite someone to Movo" }
    private var sheetSubtitle: String { invite?.description ?? "Send a join code to a contact" }
    /// Already-invited list comes from the GET-REFERRAL-LIST API (not the dashboard).
    private var invitees: [ReferralInvitee] { contactVM.referralInvitees }

    @StateObject private var transVM: TransactionViewModel
    @StateObject private var contactVM: ContactViewModel
    @State private var phoneNo: String = ""
    @State private var nickname: String = ""
    @State private var isPhoneFocused = false
    @State private var showSystemPicker = false
    @State private var showConfirm = false
    @State private var pendingInvite = false
    @State private var showMessageComposer = false

    @State private var inviteCode: String = ShareInviteSheet.randomInviteCode()

    private static let appStoreURL = "https://apps.apple.com/app/id1538828856"

    private var inviteURL: String {
        "\(AppEnvironment.sdkURL)/invite?code=\(inviteCode)"
    }
    
    private var inviteSMSBody: String {
        let inviter = inviterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let opener = inviter.isEmpty
            ? "You've been invited to become the next Movoian!"
            : "\(inviter) invited you to become the next Movoian!"
        return """
        \(opener)

        Download the app:
        \(Self.appStoreURL)

        Enter your code:
        \(inviteCode)

        Let's MOVO!

        Android support coming soon.
        """
    }

    private var recipientE164: String {
        "+1" + String(phoneNo.filter(\.isNumber).suffix(10))
    }

    private static func randomInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    init(container: AppContainer,
         inviterName: String = "",
         invite: DashboardInviteAFriend? = nil,
         onClose: @escaping () -> Void,
         onInviteSent: @escaping () -> Void) {
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

    // MARK: - Invitees list

    private var inviteesList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LabeledDivider(text: "INVITED")

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xs) {
                    ForEach(invitees.indices, id: \.self) { index in
                        inviteeRow(invitees[index])
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    private func inviteeRow(_ invitee: ReferralInvitee) -> some View {
        let phone = displayPhone(invitee.inviteePhone)
        let name = invitee.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = name?.isEmpty == false
        return HStack(spacing: Spacing.md) {
            // Monogram avatar: nickname's first letter, else phone's first digit.
            Text(initial(for: invitee))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.movo.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.movo.accentTint))

            VStack(alignment: .leading, spacing: 2) {
                if hasName {
                    Text(name!)
                        .textStyle(Typography.bodyCompact)
                        .foregroundColor(Color.movo.textPrimary)
                    Text(phone)
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                } else {
                    Text(phone)
                        .textStyle(Typography.bodyCompact)
                        .foregroundColor(Color.movo.textPrimary)
                }
            }

            Spacer()

            StatusPill(invitee.joined == true ? "Joined" : "Invited",
                       variant: invitee.joined == true ? .success : .neutral)
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Avatar initial — first letter of the nickname if present, otherwise the first
    /// digit of the phone number (falling back to the first character).
    private func initial(for invitee: ReferralInvitee) -> String {
        if let name = invitee.nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
           let first = name.first {
            return String(first).uppercased()
        }
        let phone = invitee.inviteePhone ?? ""
        if let digit = phone.first(where: { $0.isNumber }) {
            return String(digit)
        }
        return phone.first.map { String($0) } ?? "?"
    }

    /// Formats an E.164 US number (`+19999666666`) as `(999) 966-6666`; falls back to
    /// the raw value for anything unexpected.
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

    var body: some View {
        VStack(spacing: 0) {
            CustomSheetHeader(
                title: sheetTitle,
                subtitle: sheetSubtitle,
                systemImage: "person.badge.plus",
                iconTint: Color.movo.accent,
                iconBackground: Color.movo.accentTint,
                horizontalPadding: Spacing.xl,
                closeAction: onClose
            )

            VStack(spacing: Spacing.lg) {
                CustomPhoneField(phoneNumber: $phoneNo, isFocused: $isPhoneFocused)

                CustomTextField(text: $nickname, placeholder: "Nickname (optional)")

                LabeledDivider(text: "OR PICK FROM")

                UsePhoneContactButton {
                    isPhoneFocused = false   // dismiss keyboard before opening the picker
                    SpinnerView.showFullScreen()
                    showSystemPicker = true
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)

            // Already-invited list (from the dashboard INVITE-A-FRIEND section).
            if !invitees.isEmpty {
                inviteesList
                    .padding(.top, Spacing.xl)
            }

            Spacer()

            Button {
                sendInviteTapped()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("CONTINUE")
                        .tracking(1.5)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
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
                    guard MFMessageComposeViewController.canSendText() else {
                        ToastManager.shared.show(
                            "iMessage is not supported on the Simulator.",
                            style: .error,
                            position: .bottom
                        )
                        return
                    }
                    showMessageComposer = true
                }
            },
            onContinue: { pendingInvite = true; showConfirm = false },
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
                    // Notify the skinny processor that the invite was sent.
                    let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await contactVM.inviteUser(
                            phone: recipientE164,
                            referral: inviteCode,
                            nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
                        )
                    }

                    onInviteSent()
                }
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isPhoneFocused = true
            }
        }
        // Load the already-invited list from GET-REFERRAL-LIST.
        .task { await contactVM.loadReferralInvitees() }
        // Safety: never leave the full-screen spinner up if the sheet goes away.
        .onDisappear { SpinnerView.hideFullScreen() }
    }

    /// "SEND INVITE" — dismisses the keyboard first, then runs check-intent; on
    /// success shows the enroll popup whose buttons adapt to whether the number
    /// already belongs to a Movo user.
    private func sendInviteTapped() {
        isPhoneFocused = false   // dismiss keyboard before the network call
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

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.movo.accent)
            Text("MovoCash is on iPhone only right now. Make sure they have an iPhone before you invite them.")
                .textStyle(Typography.subtitle)
                .foregroundStyle(Color.movo.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.movo.accentTint)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                )
        )
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
