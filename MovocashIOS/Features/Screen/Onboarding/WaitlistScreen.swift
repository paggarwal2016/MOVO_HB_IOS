//
//  WaitlistScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 25/06/26.
//

import SwiftUI

struct WaitlistScreen: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    private enum Field: Hashable { case firstName, lastName, phone, email }
    @State private var focusedField: Field?
    @State private var touched: Set<Field> = []
    @State private var didAttemptSubmit = false
    @State private var scrollTarget: Field?

    private func focusBinding(_ field: Field) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { isOn in
                if isOn { focusedField = field }
                else if focusedField == field {
                    focusedField = nil
                    touched.insert(field) // blurred → eligible to show its error
                }
            }
        )
    }

    let onBack: () -> Void
    let onSubmitted: () -> Void

    init(initialPhone: String = "", onBack: @escaping () -> Void, onSubmitted: @escaping () -> Void) {
        _phoneNumber = State(initialValue: initialPhone)
        self.onBack = onBack
        self.onSubmitted = onSubmitted
    }

    private var firstInvalidField: Field? {
        [.firstName, .lastName, .phone, .email].first { validationMessage(for: $0) != nil }
    }

    private var isValidEmail: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return trimmed(email).range(of: pattern, options: .regularExpression) != nil
    }

    private var normalizedPhone: String? {
        if case .success(let e164) = PhoneNormalizer.normalizePhone(phoneNumber) { return e164 }
        return nil
    }

    private func validationMessage(for field: Field) -> String? {
        switch field {
        case .firstName:
            return trimmed(firstName).isEmpty ? "Enter your first name" : nil
        case .lastName:
            return trimmed(lastName).isEmpty ? "Enter your last name" : nil
        case .email:
            if trimmed(email).isEmpty { return "Enter your email address" }
            return isValidEmail ? nil : "Enter a valid email address"
        case .phone:
            if case .failure(let error) = PhoneNormalizer.normalizePhone(phoneNumber) {
                return error.errorDescription
            }
            return nil
        }
    }

    private func displayedError(for field: Field) -> String? {
        guard touched.contains(field) || didAttemptSubmit else { return nil }
        return validationMessage(for: field)
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.lg)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                                .padding(.bottom, DesignTokens.Spacing.xxl)

                            firstNameField
                                .id(Field.firstName)
                                .padding(.bottom, DesignTokens.Spacing.xl)

                            lastNameField
                                .id(Field.lastName)
                                .padding(.bottom, DesignTokens.Spacing.xl)

                            phoneField
                                .id(Field.phone)
                                .padding(.bottom, DesignTokens.Spacing.xl)

                            emailField
                                .id(Field.email)
                                .padding(.bottom, DesignTokens.Spacing.md)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) { field in
                        guard let field else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                    .onChange(of: scrollTarget) { field in
                        guard let field else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                        scrollTarget = nil
                    }
                }

                submitButton
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            StatusBarScrim()
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
        .fullScreenCover(isPresented: $showSuccess) {
            WaitlistSuccessView() {
                showSuccess = false
                onSubmitted()
            }
        }
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
            Text("Join the Waitlist")
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
            CustomTextField(
                text: $firstName,
                placeholder: "Your first name",
                isFocused: focusBinding(.firstName),
                errorMessage: displayedError(for: .firstName)
            )
        }
    }

    private var lastNameField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Last name")
            CustomTextField(
                text: $lastName,
                placeholder: "Your last name",
                isFocused: focusBinding(.lastName),
                errorMessage: displayedError(for: .lastName)
            )
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Email")
            CustomTextField(
                text: $email,
                placeholder: "you@email.com",
                keyboardType: .emailAddress,
                isFocused: focusBinding(.email),
                errorMessage: displayedError(for: .email)
            )
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Phone number")
            CustomPhoneField(
                phoneNumber: $phoneNumber,
                isFocused: focusBinding(.phone),
                errorMessage: displayedError(for: .phone)
            )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Text("Join Waitlist")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.45 : 1.0)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: isSubmitting)
    }

    private func submit() {
        guard !isSubmitting else { return }
        didAttemptSubmit = true
        if let firstInvalid = firstInvalidField {
            scrollTarget = firstInvalid // scroll into view without popping the keyboard
            return
        }

        UIApplication.shared.dismissKeyboard()
        guard let phone = normalizedPhone else { return }
        isSubmitting = true
        SpinnerView.showFullScreen()
        Task {
            do {
                let message = try await authVM.joinTheWaitList(
                    firstName: trimmed(firstName),
                    lastName: trimmed(lastName),
                    email: trimmed(email),
                    phoneNumber: phone
                )
                SpinnerView.hideFullScreen()
                isSubmitting = false
                successMessage = message ?? "We'll email you when MovoCash opens up."
                showSuccess = true
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
