//
//  SetPasswordScreen.swift
//  MovocashIOS
//
//  Registration step shown immediately after the email address is verified.
//  Collects the account's initial password and submits it via
//  AuthViewModel.setInitialPassword (POST /auth/initial-password). On success the
//  parent continues the existing registration flow unchanged.
//
//  Mandatory step — there is no back button; the user must set a valid password
//  to proceed.
//

import SwiftUI

struct SetPasswordScreen: View {

    /// Called with the validated password. The parent performs the API call and
    /// navigates on success, returning `true`; on failure it returns `false` (after
    /// surfacing the error) so this screen clears its submitting state for a retry.
    let onSubmit: (String) async -> Bool
    let onBack: () -> Void

    @State private var password = ""
    @State private var confirm = ""
    @State private var revealPassword = false
    @State private var revealConfirm = false
    @State private var isSubmitting = false

    // MARK: - Password Policy (8+, upper, lower, number, special)

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasUpper: Bool { password.contains(where: { $0.isUppercase }) }
    private var hasLower: Bool { password.contains(where: { $0.isLowercase }) }
    private var hasDigit: Bool { password.contains(where: { $0.isNumber }) }
    private var hasSpecial: Bool {
        password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
    }
    private var meetsPolicy: Bool {
        hasMinLength && hasUpper && hasLower && hasDigit && hasSpecial
    }
    private var passwordsMatch: Bool { !confirm.isEmpty && password == confirm }
    private var canContinue: Bool { meetsPolicy && passwordsMatch && !isSubmitting }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: 24) {

                topBar
                    .padding(.top, Spacing.sm)

                header
                    .padding(.bottom, Spacing.xl)

                VStack(alignment: .leading, spacing: 0) {
                    secureField(title: "Password", text: $password, reveal: $revealPassword)
                        .padding(.bottom, Spacing.lg)

                    secureField(title: "Confirm password", text: $confirm, reveal: $revealConfirm)
                        .padding(.bottom, Spacing.lg)

                    requirements

                    Spacer()
                }

                Button {
                    UIApplication.shared.dismissKeyboard()
                    guard canContinue else { return }
                    isSubmitting = true
                    Task {
                        _ = await onSubmit(password)
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(Color.movo.onAccent)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1.0 : 0.45)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            CustomBackButton() {
                UIApplication.shared.dismissKeyboard()
                onBack()
            }
            Spacer()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Set your password")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("Create a password to secure your account.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }

    // MARK: - Secure Field (visual treatment matches CustomTextField)

    @ViewBuilder
    private func secureField(title: String, text: Binding<String>, reveal: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(title)
            HStack(spacing: Spacing.sm) {
                Group {
                    if reveal.wrappedValue {
                        TextField("", text: text)
                    } else {
                        SecureField("", text: text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textPrimary)
                .tint(Color.movo.accent)

                Button {
                    reveal.wrappedValue.toggle()
                } label: {
                    Image(systemName: reveal.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(Color.movo.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
            )
        }
    }

    // MARK: - Live Requirements Checklist

    private var requirements: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            requirementRow("At least 8 characters", hasMinLength)
            requirementRow("An uppercase and a lowercase letter", hasUpper && hasLower)
            requirementRow("A number", hasDigit)
            requirementRow("A special character", hasSpecial)
            requirementRow("Passwords match", passwordsMatch)
        }
        .padding(.top, Spacing.sm)
    }

    private func requirementRow(_ text: String, _ met: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(met ? Color.movo.accent : Color.movo.textTertiary)
            Text(text)
                .textStyle(Typography.captionSmall)
                .foregroundStyle(met ? Color.movo.textPrimary : Color.movo.textTertiary)
        }
    }
}
