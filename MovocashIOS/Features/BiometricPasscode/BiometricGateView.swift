//
//  BiometricGateView.swift
//  MovocashIOS
//
//  Biometric-only gate view. Used in two contexts:
//
//    1. Cold-launch flow case (.appLock) — autoTriggerBiometric defaults
//       to false because postBootstrap already prompted Face ID on splash.
//       User taps Try Again to retry.
//
//    2. Warm-transition lock overlay (RootView ZStack) — pass
//       autoTriggerBiometric: true so Face ID prompts automatically
//       when the overlay appears.
//
//  On success, loginWithBiometric centrally calls
//  lockManager.unlockAfterRSAAuth() which dismisses the overlay via
//  state → .unlocked. On failure, user can Try Again or fall back to
//  phone-OTP via "Use phone number instead."
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
            MovoBackground()
            AmbientGlowView()

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
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if autoTriggerBiometric {
                await attempt()
            }
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
