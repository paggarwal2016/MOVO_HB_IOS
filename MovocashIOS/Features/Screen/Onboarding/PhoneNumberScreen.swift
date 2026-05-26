//
//  PhoneNumberScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct PhoneNumberScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @FocusState private var phoneFieldFocused: Bool
    @State private var externalError: String?
    private var hasError: Bool { externalError != nil }
    let flowType: PhoneFlowType
    
    init(flowType: PhoneFlowType) {
        self.flowType = flowType
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                topBar
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, DesignTokens.Spacing.xxl)
                        
                        phoneField
                            .padding(.bottom, DesignTokens.Spacing.sm + 2)
                        
                        helperLine
                            .padding(.bottom, DesignTokens.Spacing.xxl)
                        
                        Spacer()
                        
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl + 60)
                
                continueButton
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
            
            if authVM.state == .loading {
                SpinnerView()
            }
        }
        .onAppear() {
            authVM.reset()
            appState.context = flowType
            phoneFieldFocused = true
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("What's your mobile number?")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("We'll text you a 6-digit code to verify it's you.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }
            
    // MARK: - Phone field

    private var phoneField: some View {
        HStack(spacing: 0) {

            Button(action: { }) {
                HStack(spacing: 6) {
                    Text("+1")
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Color.movo.textPrimary)
                }
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.movo.accentSoft)
                .frame(width: DesignTokens.Stroke.hairline)
                .padding(.vertical, 10)

            TextField(
                "",
                text: $authVM.phoneDisplayText,
                prompt: Text("(555) 123-4567")
                    .foregroundColor(
                        Color.movo.textTertiary.opacity(0.5)
                    )
            )
            .onChangeCompat(of: authVM.phoneDisplayText) { newValue in
                authVM.handlePhoneInput(newValue)
            }
            .keyboardType(.numberPad)
            .textContentType(.telephoneNumber)
            .textStyle(Typography.cardTitle)
            .foregroundStyle(Color.movo.textPrimary)
            .tint(Color.movo.accent)
            .focused($phoneFieldFocused)
            .padding(.horizontal, 14)
            .frame(
                maxWidth: .infinity,
                minHeight: 56,
                alignment: .leading
            )
            .textFieldStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
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
        .animation(
            .easeOut(duration: DesignTokens.Motion.fast),
            value: phoneFieldFocused
        )
        .animation(
            .easeOut(duration: DesignTokens.Motion.fast),
            value: hasError
        )
    }
    
    private var fieldBorderColor: Color {
        if hasError {
            return Color.movo.danger
        }
        if phoneFieldFocused {
            return Color.movo.accent.opacity(0.55)
        }
        return Color.movo.borderStrong
    }
    
    private var fieldBorderWidth: CGFloat {
        if hasError || phoneFieldFocused { return DesignTokens.Stroke.medium }
        return DesignTokens.Stroke.hairline
    }
    
    // MARK: - Helper line (SMS rates OR error)
    
    @ViewBuilder
    private var helperLine: some View {
        if let error = externalError {
            HStack(alignment: .top, spacing: 6) {
                ErrorBadgeIcon(size: 14, tint: Color.movo.danger)
                    .padding(.top, 1)
                Text(error)
                    .textStyle(Typography.caption)
                    .foregroundStyle(Color.movo.danger)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
            .transition(.opacity)
        }
    }
            
    private var continueButton: some View {
        return Button(action: {
            UIApplication.shared.dismissKeyboard()
            Task {
                await authVM.submitPhoneNumber(appState: appState)
            }
        } ) {
            Text("Continue")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(hasError)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: hasError)
    }
    
    
    private var topBar: some View {
        HStack {
            Button(action: {
                UIApplication.shared.dismissKeyboard()
                appState.flow = .choice
            }) {
                BackChevronIcon(tint: Color.movo.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}
