//
//  WaitlistScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 25/06/26.
//

import SwiftUI

/// Join-the-Waitlist screen. Collects first name, last name + email for prospective
/// users who don't have an invite, and submits via `AuthViewModel.joinTheWaitList`.
/// The parent handles the success toast + navigation through `onSubmitted`.
struct WaitlistScreen: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false

    let onBack: () -> Void
    let onSubmitted: () -> Void

    /// All three fields are required: non-empty names plus a valid email.
    private var isValid: Bool {
        !trimmed(firstName).isEmpty && !trimmed(lastName).isEmpty && isValidEmail
    }

    /// Mirrors the rule used in `SignUpViewModel` so email validation stays consistent.
    private var isValidEmail: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xxl)

                header
                    .padding(.bottom, DesignTokens.Spacing.xxl)

                firstNameField
                    .padding(.bottom, DesignTokens.Spacing.xl)

                lastNameField
                    .padding(.bottom, DesignTokens.Spacing.xl)

                emailField
                    .padding(.bottom, DesignTokens.Spacing.xxl)

                Spacer()
                submitButton
                    .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
            
            StatusBarScrim()
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
    }

    // MARK: - Top bar

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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Join the waitlist")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("We'll let you know when MovoCash opens up. No invite needed.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }

    // MARK: - Fields

    private var firstNameField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("First name")
            CustomTextField(text: $firstName, placeholder: "Your first name")
        }
    }

    private var lastNameField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Last name")
            CustomTextField(text: $lastName, placeholder: "Your last name")
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Email")
            CustomTextField(
                text: $email,
                placeholder: "you@email.com",
                keyboardType: .emailAddress
            )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Text("Join waitlist")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!isValid || isSubmitting)
        .opacity((isValid && !isSubmitting) ? 1.0 : 0.45)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: isValid)
    }

    private func submit() {
        UIApplication.shared.dismissKeyboard()
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        SpinnerView.showFullScreen()
        Task {
            do {
                let message = try await authVM.joinTheWaitList(
                    firstName: trimmed(firstName),
                    lastName: trimmed(lastName),
                    email: trimmed(email)
                )
                SpinnerView.hideFullScreen()
                isSubmitting = false
                // Confirm success with an alert; return to Choice once acknowledged.
                AlertManager.shared.showCustom(
                    title: "You're on the waitlist",
                    message: message ?? "We'll email you when MovoCash opens up.",
                    primary: "OK",
                    onPrimary: { onSubmitted() }
                )
            } catch {
                SpinnerView.hideFullScreen()
                isSubmitting = false
                AlertManager.shared.showError(error.localizedDescription)
            }
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
