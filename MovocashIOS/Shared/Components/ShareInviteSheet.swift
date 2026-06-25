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

    @StateObject private var transVM: TransactionViewModel
    @StateObject private var contactVM: ContactViewModel
    @State private var phoneNo: String = ""
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
        """
        You've been invited to join MovoCash.

        Invite code: \(inviteCode)

        Get started: \(inviteURL)

        Don't have the app yet? Download it here: \(Self.appStoreURL)
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
         onClose: @escaping () -> Void,
         onInviteSent: @escaping () -> Void) {
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
                title: "Invite someone to Movo",
                subtitle: "Send a join code to a contact",
                systemImage: "person.badge.plus",
                iconTint: Color.movo.accent,
                iconBackground: Color.movo.accentTint,
                horizontalPadding: Spacing.xl,
                closeAction: onClose
            )

            VStack(spacing: Spacing.lg) {
                CustomPhoneField(phoneNumber: $phoneNo, isFocused: $isPhoneFocused)

                LabeledDivider(text: "OR PICK FROM")

                UsePhoneContactButton {
                    isPhoneFocused = false   // dismiss keyboard before opening the picker
                    SpinnerView.showFullScreen()
                    showSystemPicker = true
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)

            Spacer(minLength: Spacing.xl)

            infoBanner
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.lg)

            Button {
                sendInviteTapped()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("SEND INVITE")
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
        .padding(.top, Spacing.xxl)
        .background(Color.movo.cardSurface.ignoresSafeArea())
        // Hosts the native contact picker; presents when `showSystemPicker` flips true.
        .background {
            PhoneContactPicker(
                isPresented: $showSystemPicker,
                onPresented: { SpinnerView.hideFullScreen() }
            ) { _, phone in
                phoneNo = Self.normalizedUSDigits(from: phone)
            }
        }
        // Invite-mode enroll popup. exists == true → number is already a Movo user,
        // so the "Send Invite" button is hidden and only Cancel shows.
        .contactEnrollPopup(
            isPresented: $showConfirm,
            title: transVM.checkIntentResult?.message ?? "",
            message: transVM.checkIntentResult?.disclaimer ?? "",
            avatarInitial: "",
            continueTitle: "Send Invite",
            cancelTitle: "Cancel",
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
                    Task { await contactVM.inviteUser(phone: recipientE164, referral: inviteCode) }

                    onInviteSent()
                }
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isPhoneFocused = true
            }
        }
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
