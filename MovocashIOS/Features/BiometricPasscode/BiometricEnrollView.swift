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
    @State private var wentToSettings = false

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
        // Two distinct alert cases:
        // 1. Permission denied — Face ID is set up on the device but the app's
        //    access was revoked in Settings → Privacy → Face ID.
        //    "Open Settings" lands on the MovoCash settings page where the toggle is visible.
        // 2. Not enrolled in iOS — the device has Face ID hardware but the user has
        //    never configured Face ID in Settings → Face ID & Passcode.
        //    "Open Settings" lands on the app settings page; the user must navigate
        //    to Face ID & Passcode manually (iOS does not allow a deeper link).
        .alert(
            lockManager.isBiometricPermissionDenied
                ? "\(displayBiometricType.displayName) Permission Required"
                : "\(displayBiometricType.displayName) Not Set Up",
            isPresented: $showSettingsAlert
        ) {
            Button("Open Settings") {
                wentToSettings = true
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            if lockManager.isBiometricPermissionDenied {
                Text("MovoCash doesn't have permission to use \(displayBiometricType.displayName).\n\nTo enable it:\n1. Tap 'Open Settings'\n2. Enable \(displayBiometricType.displayName)\n3. Return to MovoCash")
            } else {
                Text("\(displayBiometricType.displayName) isn't configured on this device.\n\nTo set it up:\n1. Tap 'Open Settings'\n2. Go to '\(displayBiometricType.displayName) & Passcode'\n3. Set up \(displayBiometricType.displayName)\n4. Return to MovoCash")
            }
        }
        // When user returns from Settings, auto-retry enrollment.
        // didBecomeActiveNotification fires after the app is fully active so LAContext
        // reflects the permission/enrollment change the user just made in Settings.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard !enrollmentSucceeded, wentToSettings else { return }
            wentToSettings = false
            Task { await enroll() }
        }
    }

    // MARK: - Enroll

    private func enroll() async {
        // Prevent double-execution during the 1.5 s success window or while a
        // previous attempt is in progress.
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
            do {
                try lockManager.revokeBiometrics()
            } catch {
                // Secure Enclave key deletion failed — local state is now
                // inconsistent (biometric enrolled locally, no RSA key on server).
                // Force the user to log out and re-enroll so both sides resync.
                errorMessage = "Enrollment failed and could not be fully rolled back. Please log out and try again."
                isEnrolling = false
                return
            }
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
