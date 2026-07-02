//
//  SignUpScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

struct SignUpScreen: View {
    @StateObject private var vm = SignUpViewModel()

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
                    .padding(.bottom, DesignTokens.Spacing.xl)
                
                // Content
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, DesignTokens.Spacing.xxl)
                    
                    emailField
                        .padding(.bottom, DesignTokens.Spacing.sm + 2)
                    
                    Spacer()
                }
                
                // Button
                Button {
                    UIApplication.shared.dismissKeyboard()
                    onContinue(vm.email)
                } label: {
                    Text("Continue")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .disabled(!vm.isValid)
                .opacity(vm.isValid ? 1.0 : 0.45)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Please enter your email")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("We'll send a verification email to confirm it's you.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }
    
    // MARK: - Email Field
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Email")
            CustomTextField(
                text: $vm.email,
                placeholder: "you@email.com",
                keyboardType: .emailAddress
            )
        }
    }
}
