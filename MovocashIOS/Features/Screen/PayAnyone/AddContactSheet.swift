//
//  AddContactSheet.swift
//  MovocashIOS
//
//  Created by Vinu on 08/05/26.
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
         onCancel: (() -> Void)? = nil
    ) {
        self.countryCode = countryCode
        self.onSave = onSave
        self.onCancel = onCancel
        _vm = StateObject(wrappedValue: container)
    }
    
    // MARK: Configuration
    
    public let countryCode: String
    public let onSave: (Result) -> Void
    public let onCancel: (() -> Void)?
    
    // MARK: State
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ContactViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field { case nickname, phone }
    
    // MARK: Body
    
    public var body: some View {
        
        VStack(spacing: 0) {
            header()
            form()
            Spacer(minLength: Spacing.lg)
            cta
        }
        .padding(.top, Spacing.xxl)
        .background(Color.movo.surface.ignoresSafeArea())
        .onAppear {
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
                    .fill(Color.movo.surface)
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
                                .fill(Color.movo.border)
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
                        .fill(Color.movo.surface)
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
    }
    
    // MARK: CTA
    
    private var cta: some View {
        Button(action: addTapped) {
            Text("Add Contact")
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
