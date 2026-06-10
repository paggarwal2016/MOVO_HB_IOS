//
//  AddContactSheet.swift
//  MovocashIOS
//
//  Created by Movo Developer on 08/05/26.
//

import Foundation
import SwiftUI
import Combine

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
         countryCode: String = "+1",
         onSave: @escaping (Result) -> Void,
         onCancel: (() -> Void)? = nil,
         onOpenSettings: (() -> Void)? = nil
    ) {
        self.countryCode = countryCode
        self.onSave = onSave
        self.onCancel = onCancel
        self.onOpenSettings = onOpenSettings
        // `container` is owned by the presenting view's @StateObject. Observe it
        // here — do NOT re-wrap in @StateObject, which would take a second
        // ownership of the same instance and over-release it (EXC_BAD_ACCESS).
        _vm = ObservedObject(wrappedValue: container)
    }

    // MARK: Configuration

    public let countryCode: String
    public let onSave: (Result) -> Void
    public let onCancel: (() -> Void)?
    /// Opens the app's Settings page (the caller injects the app-lock-aware action).
    public let onOpenSettings: (() -> Void)?

    // MARK: State

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject private var vm: ContactViewModel
    @FocusState private var focusedField: Field?
    @State private var contactSearch: String = ""
    /// Id of the contact tapped in the import list — drives the row highlight.
    @State private var selectedContactId: String? = nil

    private enum Field { case nickname, phone }
    
    // MARK: Body
    
    public var body: some View {

        VStack(spacing: 0) {
            header()
            form()
            importSection()
            cta
        }
        .background(Color.movo.cardSurface.ignoresSafeArea())
        .onAppear {
            vm.refreshAuthorization()
            if vm.contactAccess == .full || vm.contactAccess == .limited {
                Task { await vm.load() }
            }
            // Brief delay so the sheet animation completes before keyboard appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedField = .nickname
            }
        }
    }
    
    // MARK: Header
    
    private func header() -> some View {
        HStack(spacing: Spacing.md) {
            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.accentTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(Color.movo.accentBorder,
                                          lineWidth: Stroke.hairline)
                    )
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.movo.accent)
            }
            .frame(width: 38, height: 38)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Add new contact")
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
                Text("They'll appear under your contacts")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
            }
            
            Spacer()
            
            // Close button
            Button(action: cancelTapped) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.movo.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.movo.elevated.opacity(0.8))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.xl + 2)
        .padding(.top, Spacing.xxl)
        .padding(.bottom, Spacing.lg)
    }
    
    // MARK: Sub header
    
    private func subHeader() -> some View {
        HStack(spacing: Spacing.md) {
            
        }
        .padding(.horizontal, Spacing.xl + 2)
        .padding(.top, Spacing.xxl)
        .padding(.bottom, Spacing.lg)
    }
    
    // MARK: Form
    
    private func form() -> some View {
        VStack(spacing: Spacing.sm + 2) {
            
            // Nickname
            TextField(
                "",
                text: $vm.nickname,
                prompt: Text("Nickname (e.g., Mom, Roommate)")
                    .foregroundColor(Color.movo.textDisabled)
            )
            .textStyle(Typography.body)
            .foregroundColor(Color.movo.textPrimary)
            .submitLabel(.next)
            .onSubmit { focusedField = .phone }
            .focused($focusedField, equals: .nickname)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, Spacing.md + 1)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(
                                focusedField == .nickname
                                ? Color.movo.accentBorder
                                : Color.movo.border,
                                lineWidth: Stroke.hairline
                            )
                    )
            )
            
            // Phone with +1 prefix + helper text
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Spacing.sm + 2) {
                    Text(countryCode)
                        .textStyle(Typography.body)
                        .foregroundColor(Color.movo.textTertiary)
                        .padding(.trailing, Spacing.sm + 2)
                        .overlay(
                            Rectangle()
                                .fill(Color.movo.cardBorder)
                                .frame(width: Stroke.hairline)
                                .padding(.vertical, Spacing.xs),
                            alignment: .trailing
                        )
                    
                    TextField(
                        "",
                        text: $vm.phoneInput,
                        prompt: Text("(555) 000-0000")
                            .foregroundColor(Color.movo.textDisabled)
                    )
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textPrimary)
                    .keyboardType(.phonePad)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .phone)
                    .onChange(of: vm.phoneInput) { newValue in
                        vm.phoneInput = ContactViewModel.formatPhone(newValue)
                    }
                }
                .padding(.horizontal, Spacing.md + 2)
                .padding(.vertical, Spacing.md + 1)
                .background(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .fill(Color.movo.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.button)
                                .strokeBorder(
                                    focusedField == .phone
                                    ? Color.movo.accentBorder
                                    : Color.movo.border,
                                    lineWidth: Stroke.hairline
                                )
                        )
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
    
    // MARK: Import device contacts

    @ViewBuilder
    private func importSection() -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LabeledDivider(text: "OR PICK FROM")
                .padding(.bottom, Spacing.xs)

            switch vm.contactAccess {
            case .undetermined:
                permissionCard(
                    title: "Movo is better with friends",
                    message: "Find people you know already on Movo and send instantly.",
                    button: "Enable Contacts",
                    action: { Task { await vm.requestContactAccess() } }
                )
            case .denied:
                permissionCard(
                    title: "Movo is better with friends",
                    message: "Allow contact access to pick from your phone contacts.",
                    button: "Allow Access",
                    action: { onOpenSettings?() }
                )
            case .limited, .full:
                contactsList()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Styled permission card (ported from PayAnyoneView.permissionCompactCard).
    private func permissionCard(title: String, message: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: Spacing.md + 2) {

            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.movo.accentTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                    )
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color.movo.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)

                Text(message)
                    .textStyle(Typography.captionSmall)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineSpacing(1.5)
                    .padding(.bottom, Spacing.sm + 2)

                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text(button)
                            .textStyle(Typography.button)
                    }
                }
                .buttonStyle(MovoCompactButtonStyle())
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }

    @ViewBuilder
    private func contactsList() -> some View {
        let items = vm.importableContacts(matching: contactSearch)

        HStack {
            Text("FROM YOUR CONTACTS")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)
            
            Spacer()
            
            if vm.contactAccess == .limited {
                Button(action: { onOpenSettings?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Use More")
                            .textStyle(Typography.button)
                    }
                    .foregroundColor(Color.movo.accent)
                }
                .buttonStyle(.plain)
            }
        }

        // Search
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.movo.textDisabled)
            TextField("", text: $contactSearch,
                      prompt: Text("Search contacts").foregroundColor(Color.movo.textDisabled))
            .textStyle(Typography.body)
            .foregroundColor(Color.movo.textPrimary)
            .autocorrectionDisabled()
            if !contactSearch.isEmpty {
                Button { contactSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.movo.textDisabled)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color.movo.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )

        if items.isEmpty {
            Text(contactSearch.isEmpty ? "No contacts to import." : "No matches.")
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textTertiary)
                .padding(.vertical, Spacing.md)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { contact in
                        Button { selectContact(contact) } label: { contactRow(contact) }
                            .buttonStyle(.plain)
                        if contact.id != items.last?.id {
                            Rectangle().fill(Color.movo.border)
                                .frame(height: Stroke.hairline)
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }

    private func contactRow(_ contact: ContactRecord) -> some View {
        let isSelected = contact.id == selectedContactId
        return HStack(spacing: Spacing.md) {
            Text(contact.initials.isEmpty ? "?" : contact.initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.movo.textPrimary)
                .frame(width: 38, height: 38)
                .background(Color.movo.elevated, in: Circle())
                .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.nickname ?? "")
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                Text(contact.phoneNumber ?? "")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineLimit(1)
            }
            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.movo.accent)
            }
        }
        .padding(.vertical, Spacing.sm + 2)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(isSelected ? Color.movo.accentTint : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func selectContact(_ contact: ContactRecord) {
        if selectedContactId == contact.id {
            // Tapping the selected contact again deselects it and clears the fields.
            selectedContactId = nil
            vm.clear()
        } else {
            vm.fill(from: contact)
            selectedContactId = contact.id
        }
        focusedField = nil
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
        guard let result = vm.buildResult(countryCode: countryCode) else {
            vm.helperIsError = true
            return
        }
        focusedField = nil
        // Hand off to the caller, which owns the async create-contact Task and
        // the loading spinner, then dismiss immediately (proven crash-free flow).
        onSave(result)
        dismiss()
    }
    
    private func cancelTapped() {
        focusedField = nil
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
            Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
        }
    }
}
