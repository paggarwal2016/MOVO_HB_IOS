//
//  EnterInviteCodeScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 25/06/26.
//

import SwiftUI

struct EnterInviteCodeScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel

    /// The code currently in the field (sanitized to ≤6 uppercase alphanumerics).
    @State private var code: String = ""
    @FocusState private var codeFieldFocused: Bool

    let flowType: PhoneFlowType

    init(flowType: PhoneFlowType) {
        self.flowType = flowType
    }

    /// A valid code is exactly 6 alphanumeric characters (shared rule).
    private var isCodeValid: Bool { DeepLinkRouter.isValidInviteCode(code) }

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

                    inviteCodeField

                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xxxl + 60)

                continueButton
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .onAppear {
            authVM.reset()
            appState.context = flowType
            prefillInviteCodeIfPossible()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Enter your invite code")
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text("Use the code from your invite text to join MovoCash.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }

    // MARK: - Invite code field

    private var inviteCodeField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Eyebrow("Invite code")

            ZStack {
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    )

                TextField("", text: $code)
                    .focused($codeFieldFocused)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(12)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.movo.textPrimary)
                    .tint(Color.movo.accent)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .padding(.horizontal, Spacing.lg)
                    .onChange(of: code) { newValue in
                        let cleaned = sanitize(newValue)
                        if cleaned != newValue { code = cleaned }
                    }
            }
            .frame(height: 80)
            .contentShape(RoundedRectangle(cornerRadius: Radius.xl))
            .onTapGesture { codeFieldFocused = true }
        }
    }

    /// Green when the code is valid, accent-border while focused, neutral otherwise.
    private var borderColor: Color {
        if isCodeValid { return Color.movo.accent }
        return codeFieldFocused ? Color.movo.accentBorder : Color.movo.border
    }

    private var borderWidth: CGFloat {
        (isCodeValid || codeFieldFocused) ? Stroke.medium : Stroke.thin
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button {
            UIApplication.shared.dismissKeyboard()
            // Carry the referral code through the flow (survives the phone screen's
            // authVM.reset()); it's included in the Send OTP request during registration.
            appState.referralCode = code
            appState.flow = .getStartedPhone
        } label: {
            Text("Continue")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!isCodeValid)
        .opacity(isCodeValid ? 1 : 0.5)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: isCodeValid)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            CustomBackButton() {
                UIApplication.shared.dismissKeyboard()
                appState.flow = .choice
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    /// Keep only uppercase letters/digits, capped at the 6-character code length.
    private func sanitize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
    }

    /// On appear, autofill the code from a pending invite captured by a deep link.
    /// Otherwise focus the field for manual entry. The clipboard is intentionally
    /// not read — doing so triggers iOS's system "would like to paste" prompt every
    /// time the screen opens; users paste manually via the keyboard if they wish.
    private func prefillInviteCodeIfPossible() {
        guard code.isEmpty else { return }

        if let pending = DeepLinkRouter.shared.pendingInviteCode,
           DeepLinkRouter.isValidInviteCode(pending) {
            code = pending.uppercased()
            return
        }

        // Nothing to prefill — focus for manual entry.
        codeFieldFocused = true
    }
}
