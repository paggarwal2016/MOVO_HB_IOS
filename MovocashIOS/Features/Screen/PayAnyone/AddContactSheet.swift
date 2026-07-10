//
//  AddContactSheet.swift
//  MovocashIOS
//
//  Created by Movo Developer on 08/05/26.
//

import Foundation
import SwiftUI
import Combine
import Contacts
import ContactsUI

// MARK: - Public sheet view

public struct AddContactSheet: View {
    
    /// Returned to the caller's `onSave` closure when the user taps Add Contact.
    public struct Result: Sendable, Equatable {
        public let nickname: String
        public let phoneE164: String   // e.g. "+15555550199"
        public let countryCode: String // e.g. "+1"
        public let nationalNumber: String  // raw digits, no formatting
    }
    
    // MARK: Public init
    
    init(container: ContactViewModel,
         payeeFlow: PayeeTransferModel,
         isSubmitting: Binding<Bool>,
         countryCode: String = "+1",
         onSave: @escaping (Result) -> Void,
         onContinue: @escaping () -> Void = {},
         onCancel: (() -> Void)? = nil,
         onOpenSettings: (() -> Void)? = nil
    ) {
        self.countryCode = countryCode
        self.onSave = onSave
        self.onContinue = onContinue
        self.onCancel = onCancel
        self.onOpenSettings = onOpenSettings
        _isSubmitting = isSubmitting
        _vm = ObservedObject(wrappedValue: container)
        _payeeFlow = ObservedObject(wrappedValue: payeeFlow)
    }

    // MARK: Configuration

    public let countryCode: String
    public let onSave: (Result) -> Void
    /// Continue tapped in the in-sheet enroll popup — the caller dismisses this sheet
    /// (the transfer is then presented from the sheet's `onDismiss`).
    public let onContinue: () -> Void
    public let onCancel: (() -> Void)?
    /// Opens the app's Settings page (the caller injects the app-lock-aware action).
    public let onOpenSettings: (() -> Void)?

    // MARK: State

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject private var vm: ContactViewModel
    /// Shared payee flow — drives the in-sheet enroll popup (`showAddConfirm`) shown
    /// after check-intent succeeds.
    @ObservedObject private var payeeFlow: PayeeTransferModel
    /// Owned by the caller. True while the caller runs create-contact → check-intent.
    /// The sheet stays open and shows a loading overlay until the enroll popup appears
    /// (success) or this flag clears (failure).
    @Binding private var isSubmitting: Bool
    /// Focus flags bridged into the reusable fields (CustomTextField / CustomPhoneField).
    /// Setting one true focuses that field; the system clears the other automatically.
    @State private var nicknameFocused = false
    @State private var phoneFocused = false
    /// Drives presentation of the native `CNContactPickerViewController`.
    @State private var showSystemPicker = false
    /// True between tapping "Use phone contact" and the picker finishing presenting —
    /// shows a loader during the picker's (out-of-process) launch delay.
    @State private var isOpeningPicker = false

    /// Clears focus on both fields (dismisses the keyboard).
    private func dismissKeyboard() {
        nicknameFocused = false
        phoneFocused = false
    }
    
    // MARK: Body
    
    public var body: some View {

        VStack(spacing: 0) {
            header()
            usePhoneContactButton()
                .padding(.bottom, Spacing.lg)
            LabeledDivider(text: "OR ENTER PHONE NUMBER")
            form()
            Spacer()
            cta
        }
        .background(Color.movo.cardSurface.ignoresSafeArea())
        .trackScreen(AnalyticsScreen.addContact)
        // Hosts the native contact picker; presents when `showSystemPicker` flips true.
        .background {
            PhoneContactPicker(
                isPresented: $showSystemPicker,
                onPresented: { isOpeningPicker = false }
            ) { name, phone in
                applyPickedContact(name: name, phone: phone)
            }
        }
        // Loading overlay while the caller runs create-contact → check-intent,
        // or while the native contact picker is launching.
        .overlay {
            if isSubmitting || isOpeningPicker {
                SpinnerView()
            }
        }
        // Enroll popup, shown OVER this sheet once check-intent succeeds. Continue
        // dismisses both (the caller dismisses the sheet); Cancel stays on the sheet.
        .overlay {
            CustomContactEnrollView(
                isPresented: Binding(
                    get: { payeeFlow.showAddConfirm },
                    set: { if !$0 { payeeFlow.showAddConfirm = false } }
                ),
                title: payeeFlow.confirmTitle,
                message: payeeFlow.confirmMessage,
                avatarInitial: payeeFlow.confirmInitial,
                continueTitle: "Continue",
                cancelTitle: "Cancel",
                continueAction: {
                    payeeFlow.confirmAdd()
                    onContinue()
                },
                cancelAction: { payeeFlow.cancelAdd() }
            )
        }
        .onAppear {
            vm.refreshAuthorization()
            if vm.contactAccess == .full || vm.contactAccess == .limited {
                Task { await vm.load() }
            }
            // Brief delay so the sheet animation completes before keyboard appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                nicknameFocused = true
            }
        }
    }
    
    // MARK: Header
    
    private func header() -> some View {
        CustomSheetHeader(
            title: "Add new contact",
            subtitle: "They'll appear under your contacts",
            systemImage: "person.badge.plus",
            iconTint: Color.movo.accent,
            iconBackground: Color.movo.accentTint,
            horizontalPadding: Spacing.lg
        ) {
            cancelTapped()
        }
    }
    
    // MARK: Use phone contact

    /// Opens the native system contact picker (no Contacts permission required).
    private func usePhoneContactButton() -> some View {
        UsePhoneContactButton {
            dismissKeyboard()
            isOpeningPicker = true
            showSystemPicker = true
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    /// Fills the form from a contact picked in the native system picker.
    private func applyPickedContact(name: String, phone: String) {
        let sanitized = PhoneNumberValidator.sanitize(phone)
        vm.nickname = name
        vm.phoneInput = ContactViewModel.formatPhone(sanitized)
        vm.helperIsError = false
    }

    // MARK: Form
    
    private func form() -> some View {
        VStack(spacing: Spacing.sm + 2) {

            // Nickname — reuses the shared field; advances focus to phone on "Next".
            CustomTextField(
                text: $vm.nickname,
                placeholder: "Nickname (optional)",
                cornerRadius: Radius.button,
                autocapitalization: .sentences,
                submitLabel: .next,
                isFocused: $nicknameFocused,
                onSubmit: { phoneFocused = true }
            )

            // Phone with +1 prefix + helper text
            VStack(alignment: .leading, spacing: 6) {
                CustomPhoneField(
                    phoneNumber: $vm.phoneInput,
                    countryCode: countryCode,
                    cornerRadius: Radius.button,
                    isFocused: $phoneFocused
                )

                // Helper text — fades to red if validation fails after first attempt
                Text(vm.helperMessage)
                    .textStyle(Typography.caption)
                    .foregroundColor(vm.helperIsError
                                     ? Color.movo.danger
                                     : Color.movo.textTertiary)
                    .padding(.leading, 2)
                    .animation(.easeInOut(duration: DesignTokens.Motion.fast),
                               value: vm.helperIsError)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }

    // MARK: CTA

    private var cta: some View {
        Button(action: addTapped) {
            Text("Add & Continue")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!vm.canSubmit)
        .opacity(vm.canSubmit ? 1.0 : 0.45)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: Actions

    private func addTapped() {
        guard !isSubmitting else { return }
        guard let result = vm.buildResult(countryCode: countryCode) else {
            vm.helperIsError = true
            return
        }
        dismissKeyboard()
        // Hand off to the caller, which owns the async create-contact → check-intent
        // Task. The sheet stays open (showing the loading CTA) and is dismissed by the
        // caller only after check-intent succeeds; on failure it remains open.
        onSave(result)
    }
    
    private func cancelTapped() {
        dismissKeyboard()
        vm.clear()
        onCancel?()
        dismiss()
    }
}

// MARK: - Reusable labeled divider ("──  LABEL  ──")

struct LabeledDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
            Text(text)
                .textStyle(Typography.micro)
                .foregroundColor(Color.movo.textTertiary)
                // Keep the label on one line at its intrinsic width so the flexible
                // side rules can't squeeze it into wrapping.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
        }
    }
}

// MARK: - Reusable "Use phone contact" button

/// Tappable row that opens the native system contact picker. The caller owns the
/// `CNContactPickerViewController` presentation (via `PhoneContactPicker`) and decides
/// what `action` does (e.g. flip a `showSystemPicker` flag).
struct UsePhoneContactButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Use phone contacts")
                    .textStyle(Typography.button)
                Spacer()
                MovoChevron(.disclosure, color: Color.movo.textDisabled)
            }
            .foregroundColor(Color.movo.accent)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.accentTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native system contact picker

/// Wraps `CNContactPickerViewController` so a contact (and a specific phone
/// number) can be picked from the system UI. Runs out-of-process — it does NOT
/// require the app to hold Contacts permission.
///
/// Presented from an otherwise-empty host controller (rather than via `.sheet`)
/// so the picker's own self-dismissal stays in sync with `isPresented`.
struct PhoneContactPicker: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    /// Fired once the picker has finished presenting — lets callers dismiss a loader
    /// shown during the (out-of-process) launch delay. Declared before `onPick` so the
    /// trailing-closure call sites still bind their closure to `onPick`.
    var onPresented: (() -> Void)? = nil
    /// Called with the contact's display name and the selected raw phone number.
    let onPick: (String, String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        // Present once per `isPresented` rising edge.
        if isPresented, context.coordinator.picker == nil {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            // Show phone numbers and force property-level selection so a contact
            // with multiple numbers lets the user choose which one.
            picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
            picker.predicateForSelectionOfContact = NSPredicate(value: false)
            context.coordinator.picker = picker
            let onPresented = self.onPresented
            DispatchQueue.main.async {
                host.present(picker, animated: true) { onPresented?() }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let parent: PhoneContactPicker
        /// Held so we present at most once and can clear it on dismissal.
        var picker: CNContactPickerViewController?

        init(_ parent: PhoneContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contactProperty: CNContactProperty) {
            if let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue {
                let contact = contactProperty.contact
                let name = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)
                parent.onPick(name, phone)
            }
            finish()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish()
        }

        private func finish() {
            picker = nil
            parent.isPresented = false
        }
    }
}
