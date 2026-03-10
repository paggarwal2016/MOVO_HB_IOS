//
//  BiometricEnrollView.swift
//  MovocashIOS
//
//  Created by Vinu on 10/03/26.
//

import SwiftUI

struct BiometricEnrollView: View {

    let lockManager: AppLockManager
    var onEnable: () -> Void     // user tapped "Enable"
    var onSkip: () -> Void       // user tapped "Not Now"

    @State private var isEnrolling = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Image(systemName: lockManager.biometricType.systemImageName)
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(AppColors.primary)
                    .padding(.bottom, 32)

                // Title
                Text("Enable \(lockManager.biometricType.displayName)")
                    .font(.title2.bold())
                    .padding(.bottom, 12)

                // Body
                Text("Use \(lockManager.biometricType.displayName) to unlock MovoCash quickly and securely. Your biometric data never leaves this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Error
                if let err = errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 16)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 56)

                // Enable button
                Button {
                    Task { await enroll() }
                } label: {
                    Group {
                        if isEnrolling {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable \(lockManager.biometricType.displayName)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primary)
                    .clipShape(RoundedCorner(radius: 12))
                }
                .disabled(isEnrolling)
                .padding(.horizontal, 40)

                // Skip
                Button("Not Now") {
                    onSkip()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 16)

                Spacer()
            }
        }
    }

    // MARK: - Enroll

    private func enroll() async {
        isEnrolling = true
        errorMessage = nil

        // 1. Verify biometric works right now (shows system prompt)
        do {
            try await lockManager.biometricManager.evaluate(
                reason: "Confirm biometric to enable quick unlock"
            )
        } catch let err as BiometricError {
            isEnrolling = false
            switch err {
            case .userCancel, .systemCancel:
                return  // user dismissed — no error shown
            default:
                errorMessage = err.errorDescription
                return
            }
        } catch {
            isEnrolling = false
            errorMessage = error.localizedDescription
            return
        }

        // 2. Store Secure Enclave key
        do {
            try lockManager.enrollBiometrics()
            onEnable()
        } catch {
            errorMessage = error.localizedDescription
        }

        isEnrolling = false
    }
}
