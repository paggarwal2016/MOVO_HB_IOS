//
//  BiometricGateView.swift
//  MovocashIOS
//
//  Biometric-only gate view. Used in two flow contexts with two
//  visual modes:
//
//    1. Cold-launch flow case (.appLock) — autoTriggerBiometric is
//       false. Renders in retry mode: brand lockup + biometric icon
//       + Try Again button + "Use phone number" fallback. Used when
//       postBootstrap's splash-time biometric attempt failed and
//       the user needs to manually retry.
//
//    2. Warm-transition flow case (.warmRelock) — autoTriggerBiometric
//       is true. Initially renders in splash mode via MovoSplashLogo
//       (pixel-identical to SplashScreen) so the warm-transition
//       view switch from Home looks like a clean splash. Face ID
//       auto-prompts via .task. On success, view is dismissed before
//       any retry UI appears. On failure, transitions to retry mode
//       with the full BiometricGateView UI revealed.
//
//  The background (MovoBackground + AmbientGlowView) is rendered at
//  the outer ZStack level so the splash → retry mode transition
//  doesn't re-render the backdrop.
//
//  On success, loginWithBiometric centrally calls
//  lockManager.unlockAfterRSAAuth() and the onAuthenticated callback
//  sets appState.flow = .home.
//

import SwiftUI

struct BiometricGateView: View {

    let biometricIcon: String
    let biometricLabel: String
    let authenticate: () async -> Bool
    let onAuthenticated: () -> Void
    let onUsePhoneNumber: () -> Void
    var autoTriggerBiometric: Bool = false
    var apiErrorMessage: () -> String? = { nil }

    @AppStorage("appearancePreference") private var appearance: Appearance = .system
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            if showError || !autoTriggerBiometric {
                retryContent
            } else {
                MovoSplashLogo()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .task {
            RelockLog.log("BiometricGateView .task fired autoTrigger=\(autoTriggerBiometric)")
            if autoTriggerBiometric {
                await attempt(isManualRetry: false)
            }
            RelockLog.log("BiometricGateView .task exited autoTrigger=\(autoTriggerBiometric)")
        }
    }

    private var retryContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Updated brand lockup — MovoMVSymbol (current mark) + adaptive wordmark
            VStack(spacing: Spacing.lg) {
                MovoMVSymbol()
                    .frame(width: 80, height: 80)
                Text("MOVOCASH")
                    .font(FontFamily.font(size: 22, weight: .regular))
                    .tracking(8)
                    .foregroundStyle(Color.movo.textPrimary)
                    .padding(.leading, 8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("MovoCash")

            Spacer().frame(height: 60)

            Image(systemName: biometricIcon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.movo.textPrimary)

            Spacer().frame(height: 20)

            Text("Unlock with \(biometricLabel)")
                .font(Typography.cardTitle.font)
                .foregroundStyle(Color.movo.textPrimary)

            if showError {
                Spacer().frame(height: Spacing.md)
                Text("\(biometricLabel) failed. Try again or use your phone number.")
                    .font(Typography.caption.font)
                    .foregroundStyle(Color.movo.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.huge)
            }

            Spacer().frame(height: 48)

            Button {
                Task { await attempt(isManualRetry: true) }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(Color.movo.textPrimary)
                    } else {
                        Text("Try Again")
                            .font(Typography.buttonLarge.font)
                            .foregroundStyle(Color.movo.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
            .padding(.horizontal, Spacing.huge)
            .disabled(isLoading)

            Spacer().frame(height: 20)

            Button {
                onUsePhoneNumber()
            } label: {
                Text("Use phone number instead")
                    .font(Typography.subtitle.font)
                    .foregroundStyle(Color.movo.textSecondary)
                    .underline()
            }
            .disabled(isLoading)

            Spacer()
        }
    }

    private func attempt(isManualRetry: Bool) async {
        RelockLog.log("attempt isManualRetry=\(isManualRetry) isLoading=\(isLoading)")
        guard !isLoading else {
            RelockLog.log("attempt GUARD DROPPED isLoading=true")
            return
        }
        isLoading = true
        showError = false
        RelockLog.log("attempt calling authenticate()")
        let success = await authenticate()
        RelockLog.log("attempt authenticate() returned success=\(success)")
        isLoading = false
        SecureWindowShield.shared.hide(.auth)
        RelockLog.log("attempt called hide(.auth)")
        if success {
            onAuthenticated()
        } else {
            showError = true
            if isManualRetry, let message = apiErrorMessage(), !message.isEmpty {
                AlertManager.shared.showError(message)
            }
        }
    }
}
