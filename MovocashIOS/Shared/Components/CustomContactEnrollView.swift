//
//  CustomContactEnrollView.swift
//  MovocashIOS
//
//  Created by Vinu on 10/06/26.
//

import SwiftUI
import UIKit
import Combine

struct CustomContactEnrollView: View {

    @Binding var isPresented: Bool

    var title: String
    var message: String
    /// Recipient initial shown inside the avatar (e.g. "K"). Falls back to "?".
    var avatarInitial: String = ""

    var continueTitle: String
    var cancelTitle: String

    /// When false, the primary (continue) button is hidden and only Cancel shows.
    /// Used by Invite mode when the number already belongs to a Movo user.
    var showsContinue: Bool = true

    var continueAction: (() -> Void)?
    var cancelAction: (() -> Void)?

    /// Drives the center scale/fade. Animated true on appear and back to false
    /// before dismissing, so present and dismiss share the same expansion.
    @State private var shown = false

    // Semantic palette — adapts to light and dark mode via the design system.
    private var avatarFill  : Color { Color.movo.elevated }
    private var avatarText  : Color { Color.movo.textTertiary }
    private var titleColor  : Color { Color.movo.textPrimary }
    private var bodyColor   : Color { Color.movo.textSecondary }

    var body: some View {

        if isPresented {

            ZStack {

                // Background scrim — dims the tab bar showing through the clear cover.
                Color.movo.background.opacity(shown ? 0.45 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { handleCancel() }

                // Popup card — left-aligned content
                VStack(alignment: .leading, spacing: Spacing.lg) {

                    // Avatar with Movo brand badge
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(avatarFill)
                            .frame(width: 76, height: 76)
                            .overlay {
                                if avatarInitial.isEmpty {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 34, weight: .regular))
                                        .foregroundColor(avatarText)
                                } else {
                                    Text(avatarInitial)
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundColor(avatarText)
                                }
                            }

                        Circle()
                            .fill(Color.movo.surface)
                            .frame(width: 28, height: 28)
                            .overlay {
                                AppLogo()
                                    .frame(width: 15, height: 15)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                            .offset(x: 3, y: 3)
                    }
                    .padding(.bottom, Spacing.xs)

                    // Title (API message)
                    Text(title)
                        .textStyle(Typography.cardHero)
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Message (disclaimer)
                    Text(message)
                        .textStyle(Typography.subtitle)
                        .foregroundColor(bodyColor)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Primary CTA — hidden when `showsContinue` is false.
                    if showsContinue {
                        Button(action: { handleContinue() } ) {
                            Text(continueTitle)
                        }
                        .buttonStyle(MovoPrimaryButtonStyle())
                    }

                    // Secondary CTA
                    Button(action: { handleCancel() }) {
                        Text(cancelTitle)
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.xxl + Spacing.xs)
                .frame(maxWidth: 340)
                .background(Color.movo.cardSurface)
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
                .padding(.horizontal, Spacing.xxl)
                .scaleEffect(shown ? 1 : 0.8)   // expands from / contracts to center
                .opacity(shown ? 1 : 0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { shown = true }
            }
        }
    }

    /// Animate the card back to center, then run the action (which removes the cover).
    private func handleContinue() { animateOut { continueAction?() } }
    private func handleCancel()   { animateOut { cancelAction?() } }

    private func animateOut(_ then: @escaping () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { then() }
    }
}

// MARK: - Presentation modifier

extension View {

    /// Presents `CustomContactEnrollView` above everything — including the tab bar —
    /// using a transparent full-screen cover. The tab bar stays in place behind the
    /// popup but is dimmed by the scrim and not interactive. Implemented as a view
    /// modifier so callers just attach `.contactEnrollPopup(...)`.
    func contactEnrollPopup(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        avatarInitial: String,
        continueTitle: String = "Continue",
        cancelTitle: String = "Cancel",
        showsContinue: Bool = true,
        onDismiss: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(
            ContactEnrollPopupModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                avatarInitial: avatarInitial,
                continueTitle: continueTitle,
                cancelTitle: cancelTitle,
                showsContinue: showsContinue,
                onDismiss: onDismiss,
                onContinue: onContinue,
                onCancel: onCancel
            )
        )
    }
}

private struct ContactEnrollPopupModifier: ViewModifier {

    @Binding var isPresented: Bool
    let title: String
    let message: String
    let avatarInitial: String
    let continueTitle: String
    let cancelTitle: String
    let showsContinue: Bool
    let onDismiss: (() -> Void)?
    let onContinue: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                CustomContactEnrollView(
                    isPresented: $isPresented,
                    title: title,
                    message: message,
                    avatarInitial: avatarInitial,
                    continueTitle: continueTitle,
                    cancelTitle: cancelTitle,
                    showsContinue: showsContinue,
                    continueAction: onContinue,
                    cancelAction: onCancel
                )
                .background(ClearCoverBackground())
            }
    }
}

/// Makes the hosting full-screen cover transparent so the underlying UI (incl. the
/// tab bar) shows through the scrim instead of an opaque system background.
private struct ClearCoverBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { BackgroundClearingView() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class BackgroundClearingView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The cover's hosting view is two levels up; clear it so only our scrim shows.
            superview?.superview?.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
    }
}

// MARK: - Centralized payee → check-intent → confirm → transfer flow

/// Owns the shared "tap a payee → check-intent → confirm popup → QuickTransferView"
/// flow so each screen (Pay Anyone, See all, …) only has to call `tap(_:)` and attach
/// `.payeeTransferFlow(...)`. Keeps a single check-intent call per tap and routes the
/// transfer using its result.
@MainActor
final class PayeeTransferModel: ObservableObject {
    /// True while check-intent runs for a tapped payee — drives the spinner.
    @Published fileprivate var isChecking = false
    /// Drives the Continue/Cancel confirmation popup.
    @Published fileprivate var showPopup = false
    /// The payee awaiting confirmation (populates the popup).
    @Published fileprivate var confirmingContact: ContactRecord?
    /// The payee to open in QuickTransferView (set after the popup fully dismisses).
    @Published fileprivate var transferContact: ContactRecord?

    /// Drives the enroll popup rendered INSIDE the Add Contact sheet after check-intent
    /// succeeds. Kept separate from `showPopup` (the parent-level popup used by the
    /// normal payee-tap flow) so the two presentation sites never collide.
    @Published var showAddConfirm = false

    /// Contact to open once the popup's dismiss transition completes (Continue).
    private var pendingTransfer: ContactRecord?

    let transactionVM: TransactionViewModel

    init(container: AppContainer) {
        transactionVM = container.makeTransactionViewModel()
    }

    /// Entry point — call from any payee row tap. Runs check-intent, then shows the
    /// confirmation popup. On failure only the error toast shows (no popup).
    func tap(_ contact: ContactRecord) {
        // Set synchronously (not inside the Task) so the spinner shows immediately on
        // tap with no scheduling gap — lets callers hand off a loader continuously.
        isChecking = true
        Task {
            let raw = contact.phoneNumber ?? ""
            let withCountry = raw.hasPrefix("+1") ? raw : "+1\(raw.filter(\.isNumber))"
            let normalized = PhoneNumberValidator.normalize(PhoneNumberValidator.sanitize(withCountry))
            await transactionVM.checkIntent(phoneNumber: normalized)
            isChecking = false
            guard transactionVM.checkIntentResult != nil else { return }
            confirmingContact = contact
            setPopup(true)
        }
    }

    fileprivate func confirm() {
        pendingTransfer = confirmingContact
        confirmingContact = nil
        setPopup(false)   // navigation fires in popupDidDismiss() after the card animates out
    }

    fileprivate func cancel() {
        pendingTransfer = nil
        confirmingContact = nil
        setPopup(false)
    }

    /// Show/hide the cover without its own slide — the card runs the center
    /// scale/fade animation itself, on both present and dismiss.
    private func setPopup(_ visible: Bool) {
        // Qualify SwiftUI.Transaction — the app also defines a `Transaction` model.
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { showPopup = visible }
    }

    /// Called when the popup (or the Add Contact sheet) finishes dismissing. Presenting
    /// the transfer screen here (not on a timer) avoids presenting while the cover is
    /// still sliding. No-op unless a transfer is pending (e.g. plain Cancel/close).
    func popupDidDismiss() {
        guard let contact = pendingTransfer else { return }
        pendingTransfer = nil
        transferContact = contact
    }

    /// Content accessors for the in-sheet enroll popup (`showAddConfirm`).
    var confirmTitle: String { transactionVM.checkIntentResult?.message ?? "" }
    var confirmMessage: String { transactionVM.checkIntentResult?.disclaimer ?? "" }
    var confirmInitial: String { confirmingContact?.initials ?? "" }

    /// Runs check-intent for a newly added contact and, on success, raises the in-sheet
    /// enroll popup (`showAddConfirm`) WITHOUT dismissing the Add Contact sheet. Returns
    /// false on failure so the caller keeps the sheet open. The error toast is surfaced
    /// by check-intent.
    @discardableResult
    func prepareConfirmation(for contact: ContactRecord) async -> Bool {
        isChecking = true
        let raw = contact.phoneNumber ?? ""
        let withCountry = raw.hasPrefix("+1") ? raw : "+1\(raw.filter(\.isNumber))"
        let normalized = PhoneNumberValidator.normalize(PhoneNumberValidator.sanitize(withCountry))
        await transactionVM.checkIntent(phoneNumber: normalized)
        isChecking = false
        guard transactionVM.checkIntentResult != nil else { return false }
        confirmingContact = contact
        showAddConfirm = true
        return true
    }

    /// Continue tapped in the in-sheet enroll popup: arm the transfer and hide the popup.
    /// The caller dismisses the Add Contact sheet; the transfer is presented from the
    /// sheet's `onDismiss` via `popupDidDismiss()`.
    func confirmAdd() {
        pendingTransfer = confirmingContact
        confirmingContact = nil
        showAddConfirm = false
    }

    /// Cancel tapped in the in-sheet enroll popup: hide the popup and stay on the sheet.
    func cancelAdd() {
        pendingTransfer = nil
        confirmingContact = nil
        showAddConfirm = false
    }

    /// Clears all flow state (e.g. on session expiry / returning to the dashboard).
    func reset() {
        isChecking = false
        showPopup = false
        confirmingContact = nil
        pendingTransfer = nil
        transferContact = nil
        showAddConfirm = false
    }
}

extension View {

    /// Attaches the shared payee transfer flow: a check-intent spinner, the
    /// confirmation popup, and the QuickTransferView cover. Trigger it from any
    /// payee row with `model.tap(contact)`.
    func payeeTransferFlow(
        _ model: PayeeTransferModel,
        container: AppContainer,
        cards: [VCardListResponse],
        primaryLinkedCard: VCardListResponse?,
        onSuccess: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            PayeeTransferFlowModifier(
                model: model,
                container: container,
                cards: cards,
                primaryLinkedCard: primaryLinkedCard,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        )
    }
}

private struct PayeeTransferFlowModifier: ViewModifier {
    
    @ObservedObject var model: PayeeTransferModel
    let container: AppContainer
    let cards: [VCardListResponse]
    let primaryLinkedCard: VCardListResponse?
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if model.isChecking { SpinnerView() }
            }
            .contactEnrollPopup(
                isPresented: $model.showPopup,
                title: model.transactionVM.checkIntentResult?.message ?? "",
                message: model.transactionVM.checkIntentResult?.disclaimer ?? "",
                avatarInitial: model.confirmingContact?.initials ?? "",
                onDismiss: { model.popupDidDismiss() },
                onContinue: { model.confirm() },
                onCancel: { model.cancel(); onCancel() }
            )
            .fullScreenCover(item: $model.transferContact) { contact in
                QuickTransferView(
                    contact: contact,
                    container: container,
                    cards: cards,
                    primaryLinkedCard: primaryLinkedCard,
                    recipientExists: model.transactionVM.checkIntentResult?.exists,
                    onComplete: { _ in onSuccess() }
                )
            }
    }
}
