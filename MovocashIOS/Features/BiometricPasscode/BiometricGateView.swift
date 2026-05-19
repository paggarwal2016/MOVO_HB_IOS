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

    let biometricIcon: String        // SF Symbol name, e.g. "faceid" / "touchid"
    let biometricLabel: String       // Display name, e.g. "Face ID"
    let authenticate: () async -> Bool
    let onAuthenticated: () -> Void
    let onUsePhoneNumber: () -> Void
    var autoTriggerBiometric: Bool = false

    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        ZStack {
            // Stable background — renders in both splash and retry modes
            // so transitions between them don't re-render the backdrop.
            MovoBackground()
            AmbientGlowView()

            if showError || !autoTriggerBiometric {
                // Retry mode — shown when auto-trigger is off (cold-launch
                // failure case) or when a biometric attempt has failed.
                retryContent
            } else {
                // Splash mode — pixel-perfect match with SplashScreen.
                // Shown briefly during warm-transition while Face ID
                // auto-prompts. Dismissed on success before any retry
                // UI ever appears.
                MovoSplashLogo()
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if autoTriggerBiometric {
                await attempt()
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
                .foregroundStyle(.white)

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
                Task { await attempt() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.white.opacity(0.15))
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

    private func attempt() async {
        guard !isLoading else { return }
        isLoading = true
        showError = false
        let success = await authenticate()
        isLoading = false
        if success {
            onAuthenticated()
        } else {
            showError = true
        }
    }
}
