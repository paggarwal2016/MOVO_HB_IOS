//
//  EmailVerificationView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 03/06/26.
//

import SwiftUI

/// Email-verification waiting screen (fintech-standard, link-based).
///
/// The verification email/link is sent before this screen appears. Here the user
/// is asked to open the link from their mailbox and return to the app. The screen
/// re-checks the verification status (`getProfile().emailVerified`) automatically
/// when the app returns to the foreground, and via an explicit "Continue" button.
///
/// All routing/policy (status interpretation, navigation, toasts, the full-screen
/// loader) lives in the parent (RootView) through the closures below; this view
/// owns presentation, re-entry guards, the foreground re-check trigger, and the
/// anti-abuse resend cooldown.
struct EmailVerificationView: View {

    /// The email the verification link was sent to (display only).
    let email: String

    /// Checks the verification status. `isExplicit` is `true` for the Continue tap
    /// (parent shows the loader and surfaces a toast on a non-verified result) and
    /// `false` for the silent foreground re-check.
    let onCheck: (_ isExplicit: Bool) async -> Void

    /// Resends the verification email.
    let onResend: () async -> Void

    /// Back navigation (returns to email entry).
    let onBack: () -> Void

    /// Seconds the resend button stays locked after a send. Throttles requests to
    /// protect the user's mailbox and stay within backend rate limits.
    private static let resendCooldownSeconds = 30

    @State private var isChecking = false
    @State private var isResending = false
    @State private var resendCooldown = 0
    @State private var cooldownTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {

                topBar
                    .padding(.top, DesignTokens.Spacing.sm)

                header

                Spacer()

                continueButton
                resendButton
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        // The email was just sent before this screen appeared — start the cooldown
        // so the user cannot immediately request another.
        .onAppear {
            if resendCooldown == 0 { startCooldown() }
        }
        .onDisappear {
            cooldownTask?.cancel()
            cooldownTask = nil
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            CustomBackButton() {
                onBack()
            }
            Spacer()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.movo.accentSoft)
                    .frame(width: 64, height: 64)
                Image(systemName: "envelope.badge")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.movo.accent)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Verify your email")
                    .textStyle(Typography.heroTitle)
                    .foregroundStyle(Color.movo.textPrimary)
                    .lineSpacing(2)

                Text("We sent a verification link to \(email). Open it to confirm your email, then come back and tap Verified.")
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Buttons

    private var continueButton: some View {
        Button {
            guard !isChecking, !isResending else { return }
            Task {
                isChecking = true
                await onCheck(true)
                isChecking = false
            }
        } label: {
            Text("Verified")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(isChecking || isResending)
        .opacity(isChecking || isResending ? 0.6 : 1.0)
    }

    private var resendButton: some View {
        Button {
            guard !isResending, resendCooldown == 0 else { return }
            Task {
                isResending = true
                await onResend()
                isResending = false
                startCooldown()
            }
        } label: {
            Text(resendLabel)
                .textStyle(Typography.buttonLarge)
                .foregroundColor(Color.movo.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isResending || resendCooldown > 0)
        .opacity(resendCooldown > 0 ? 0.5 : 1.0)
    }

    private var resendLabel: String {
        if resendCooldown > 0 { return "Resend email in \(resendCooldown)s" }
        return "Resend email"
    }

    // MARK: - Cooldown

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = Self.resendCooldownSeconds
        cooldownTask = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendCooldown -= 1
            }
        }
    }
}
