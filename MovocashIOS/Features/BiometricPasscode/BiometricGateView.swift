//
//  BiometricGateView.swift
//  MovocashIOS
//
//  Biometric-only cold-launch gate. Shown when a returning user has RSA keys
//  enrolled (Face ID / Touch ID) but no passcode is configured. Triggers
//  biometric authentication automatically on appear. On failure the user can
//  retry or fall back to phone-number login.
//

import SwiftUI

struct BiometricGateView: View {

    let biometricIcon: String        // SF Symbol name, e.g. "faceid" / "touchid"
    let biometricLabel: String       // Display name, e.g. "Face ID"
    let authenticate: () async -> Bool
    let onAuthenticated: () -> Void
    let onUsePhoneNumber: () -> Void

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
