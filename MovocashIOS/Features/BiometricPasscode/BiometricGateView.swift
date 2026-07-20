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
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .task {
            if autoTriggerBiometric {
                await attempt(isManualRetry: false)
            }
        }
    }

    private var retryContent: some View {
        VStack(spacing: 0) {
            Spacer()

            MovoBrandLockup(
                markSize: 80,
                wordmarkSize: 22,
                spacing: 16,
                color: .white,
                vertical: true
            )

            Spacer().frame(height: 60)

            Image(systemName: biometricIcon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.9))

            Spacer().frame(height: 20)

            Text("Unlock with \(biometricLabel)")
                .font(.headline)
                .foregroundStyle(Color.movo.textPrimary)

            if showError {
                Spacer().frame(height: 12)
                Text("\(biometricLabel) failed. Try again or use your phone number.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer().frame(height: 48)

            Button {
                Task { await attempt(isManualRetry: true) }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(Color.movo.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.movo.elevated.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 40)
            .disabled(isLoading)

            Spacer().frame(height: 20)

            Button {
                onUsePhoneNumber()
            } label: {
                Text("Use phone number instead")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .underline()
            }
            .disabled(isLoading)

            Spacer()
        }
    }

    private func attempt(isManualRetry: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        showError = false
        let success = await authenticate()
        isLoading = false
        SecureWindowShield.shared.hide(.auth)
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
