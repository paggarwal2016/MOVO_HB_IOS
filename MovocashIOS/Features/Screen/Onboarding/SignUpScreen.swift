//
//  SignUpScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

struct SignUpScreen: View {
    @StateObject private var vm = SignUpViewModel()
    @FocusState private var emailFocused: Bool
    @State private var externalError: String?
    private var hasError: Bool { externalError != nil }
    
    let onBack: () -> Void
    let onContinue: (String) -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            
            VStack(alignment: .leading, spacing: 24) {
                
                // Top Bar
                topBar
                    .padding(.top, DesignTokens.Spacing.sm)
                
                // Content
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, DesignTokens.Spacing.xxl)
                    
                    emailField
                        .padding(.bottom, DesignTokens.Spacing.sm + 2)
                    
                    Spacer()
                }
                
                // Button
                PrimaryButton(title: "Send code", isEnabled: vm.isValid) {
                    UIApplication.shared.dismissKeyboard()
                    onContinue(vm.email)
                }
                .frame(maxWidth: .infinity)
                .disabled(!vm.isValid)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                emailFocused = true
            }
        }
    }
    
    // MARK: - Field Styling
    
    private var fieldBorderColor: Color {
        if hasError { return Color.movo.danger }
        if emailFocused { return Color.movo.accent.opacity(0.55) }
        return Color.movo.borderStrong
    }
    
    private var fieldBorderWidth: CGFloat {
        if hasError || emailFocused { return DesignTokens.Stroke.medium }
        return DesignTokens.Stroke.hairline
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { onBack() }) {
                BackChevronIcon(tint: Color.movo.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Please enter your email")
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)
            
            Text("We'll send a verification code to confirm it's you.")
                .font(.system(size: 14))
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }
    
    // MARK: - Email Field
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Email address")
                .font(.subheadline)
                .foregroundColor(Color.movo.textTertiary)
            
            TextField("Enter your email", text: $vm.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .foregroundStyle(Color.movo.textPrimary)
                .tint(Color.movo.accent)
                .focused($emailFocused)
                .padding()
                .background(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.xl,
                        style: .continuous
                    )
                    .fill(Color.movo.surface)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.xl,
                        style: .continuous
                    )
                    .strokeBorder(
                        fieldBorderColor,
                        lineWidth: fieldBorderWidth
                    )
                )
        }
    }
}
