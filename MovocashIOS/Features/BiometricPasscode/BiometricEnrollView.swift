//
//  BiometricEnrollView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI
import UIKit

struct BiometricEnrollView: View {

    let lockManager: AppLockManager
    var onEnable: () -> Void     // user tapped "Enable"
    var onSkip: () -> Void       // user tapped "Not Now"

    @EnvironmentObject var authVM: AuthViewModel

    @State private var isEnrolling = false
    @State private var enrollmentSucceeded = false
    @State private var errorMessage: String? = nil
    @State private var showSettingsAlert = false

    // Use hardware type so the icon/name is correct even when not yet OS-enrolled
    private var displayBiometricType: BiometricType {
        lockManager.isBiometricAvailable
            ? lockManager.biometricType
            : lockManager.hardwareBiometricType
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon — checkmark on success
                Image(systemName: enrollmentSucceeded ? "checkmark.circle.fill" : displayBiometricType.systemImageName)
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(enrollmentSucceeded ? .primary : Color.primary)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.3), value: enrollmentSucceeded)

                // Title
                Text(enrollmentSucceeded
                     ? "\(displayBiometricType.displayName) Enabled"
                     : "Enable \(displayBiometricType.displayName)")
                    .font(.title2.bold())
                    .padding(.bottom, 12)
                    .animation(.easeInOut(duration: 0.3), value: enrollmentSucceeded)

                // Body
                Text(enrollmentSucceeded
                     ? "\(displayBiometricType.displayName) is now set up. You can use it to unlock MovoCash quickly and securely."
                     : "Use \(displayBiometricType.displayName) to unlock MovoCash quickly and securely. Your biometric data never leaves this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Error (hidden once enrolled)
                if !enrollmentSucceeded, let err = errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 16)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 56)

                // Enable button — becomes a filled success indicator after enroll
                Button {
                    Task { await enroll() }
                } label: {
                    Group {
                        if enrollmentSucceeded {
                            Label("Enrolled", systemImage: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                        } else if isEnrolling {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable \(displayBiometricType.displayName)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(enrollmentSucceeded ? .primary : Color.primary)
                    .clipShape(RoundedCorner(radius: 12))
                    .animation(.easeInOut(duration: 0.3), value: enrollmentSucceeded)
                }
                .disabled(isEnrolling || enrollmentSucceeded)
                .padding(.horizontal, 40)

                // Skip — hidden once enrolled
                if !enrollmentSucceeded {
                    Button("Not Now") {
                        onSkip()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
        // Alert shown when hardware exists but user hasn't configured it in iOS Settings
        // OR when app permission has been revoked in iOS Settings → Privacy → Face ID
        .alert(
            "\(displayBiometricType.displayName) Not Set Up",
            isPresented: $showSettingsAlert
        ) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            if lockManager.isBiometricPermissionDenied {
                Text("MovoCash doesn't have permission to use \(displayBiometricType.displayName).\n\nTo enable it:\n1. Tap 'Open Settings'\n2. Scroll to MovoCash\n3. Enable \(displayBiometricType.displayName)\n4. Return to MovoCash")
            } else {
                Text("\(displayBiometricType.displayName) isn't configured on this device.\n\nTo set it up:\n1. Tap 'Open Settings'\n2. Tap '\(displayBiometricType.displayName) & Passcode'\n3. Set up \(displayBiometricType.displayName)\n4. Return to MovoCash")
            }
        }
        // When user returns from Settings, auto-retry enrollment if biometrics are now available
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard lockManager.isBiometricAvailable else { return }
            Task { await enroll() }
        }
    }

    // MARK: - Enroll

    private func enroll() async {
        // Prevent double-execution: willEnterForegroundNotification can fire
        // during the 1.5 s success window and re-enter this function.
        guard !enrollmentSucceeded, !isEnrolling else { return }

        // Guard: app permission was revoked in iOS Settings → Privacy → Face ID
        if lockManager.isBiometricPermissionDenied {
            showSettingsAlert = true
            return
        }

        // Hardware present but iOS Settings enrollment is missing — redirect to Settings
        if lockManager.isBiometricHardwarePresent && !lockManager.isBiometricAvailable {
            showSettingsAlert = true
            return
        }

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
            case .notEnrolled, .notAvailable:
                // notEnrolled: state changed between check and prompt.
                // notAvailable: permission denied (safety net if isAppPermissionDenied
                // did not catch it before evaluate() was called).
                showSettingsAlert = true
                return
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
        } catch {
            errorMessage = error.localizedDescription
            isEnrolling = false
            return
        }

        // 3. Register RSA key pair with server (POST /rsa)
        await authVM.enrollRSA()

        // enrollRSA() deletes the RSA key pair on any failure.
        // If keys are absent, roll back the local Secure Enclave key so both
        // sides stay in sync — the user will need to retry enrollment.
        if !RSAKeyManager.shared.keysExist() {
            try? lockManager.revokeBiometrics()
            errorMessage = "Enrollment incomplete. Check your connection and try again."
            isEnrolling = false
            return
        }

        // Show success confirmation on this screen before navigating forward.
        // Gives the user a clear signal that enrollment completed.
        enrollmentSucceeded = true
        isEnrolling = false
        try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 s
        onEnable()
    }
}

