//
//  ChangePasswordView.swift
//  MovocashIOS
//
//  Settings screen (pushed from Profile → Change password). Collects the current
//  password and a new password, then submits via AuthViewModel.changePassword
//  (POST /auth/password). Both passwords are sealed with libsodium before transit
//  (handled in the view model). On success it shows a toast and pops back.
//

import SwiftUI

struct ChangePasswordView: View {

    @ObservedObject var authVM: AuthViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var revealCurrent = false
    @State private var revealNew = false
    @State private var revealConfirm = false
    @State private var isSubmitting = false

    // MARK: - New-password policy (8+, upper, lower, number, special)

    private var hasMinLength: Bool { newPassword.count >= 8 }
    private var hasUpper: Bool { newPassword.contains(where: { $0.isUppercase }) }
    private var hasLower: Bool { newPassword.contains(where: { $0.isLowercase }) }
    private var hasDigit: Bool { newPassword.contains(where: { $0.isNumber }) }
    private var hasSpecial: Bool {
        newPassword.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
    }
    private var meetsPolicy: Bool {
        hasMinLength && hasUpper && hasLower && hasDigit && hasSpecial
    }
    private var passwordsMatch: Bool { !confirm.isEmpty && newPassword == confirm }
    private var differsFromCurrent: Bool { !newPassword.isEmpty && newPassword != current }
    private var canSubmit: Bool {
        !current.isEmpty && meetsPolicy && passwordsMatch && differsFromCurrent && !isSubmitting
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: 24) {

                topBar
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, Spacing.xl)

                    secureField(title: "Current password", text: $current, reveal: $revealCurrent)
                        .padding(.bottom, Spacing.lg)

                    secureField(title: "New password", text: $newPassword, reveal: $revealNew)
                        .padding(.bottom, Spacing.lg)

                    secureField(title: "Confirm new password", text: $confirm, reveal: $revealConfirm)
                        .padding(.bottom, Spacing.lg)

                    requirements

                    Spacer()
                }

                Button {
                    UIApplication.shared.dismissKeyboard()
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView().tint(Color.movo.onAccent)
                    } else {
                        Text("Update password")
                    }
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1.0 : 0.45)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        Task {
            do {
                try await authVM.changePassword(current: current, new: newPassword)
                ToastManager.shared.show("Password updated.", style: .success, position: .bottom)
                dismiss()
            } catch {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
            isSubmitting = false
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            CustomBackButton() {
                UIApplication.shared.dismissKeyboard()
                dismiss()
            }
            Spacer()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Change password")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("Enter your current password and choose a new one.")
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
                .textContentType(.password)
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
            requirementRow("New password matches confirmation", passwordsMatch)
            requirementRow("Different from current password", differsFromCurrent)
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
