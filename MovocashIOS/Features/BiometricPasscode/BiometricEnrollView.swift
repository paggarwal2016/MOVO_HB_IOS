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
    var onEnable: () async -> Bool  // user tapped "Enable"; returns false if passkey was cancelled/failed
    var onSkip: () -> Void          // user tapped "Skip"
    /// Called when the user taps "Open Settings" to fix a denied/disabled biometric.
    /// The onboarding flow uses this to persist a cold-launch resume marker; other
    /// call sites (post-login settings) leave it nil.
    var onOpenSettings: (() -> Void)? = nil
    
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
            MovoBackground()
            AmbientGlowView()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                
                // Face Scan Icon
                FaceScanView(enrollmentSucceeded: enrollmentSucceeded)
                    .frame(height: 220)
                
                Spacer().frame(height: 32)
                
                // Title + Description
                VStack(spacing: 12) {
                    
                    Text(enrollmentSucceeded
                         ? "\(displayBiometricType.displayName) Enabled"
                         : "Enable \(displayBiometricType.displayName)")
                    .textStyle(Typography.balance)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    
                    Text(enrollmentSucceeded
                         ? "\(displayBiometricType.displayName) is now set up. You can use it to unlock MovoCash quickly and securely."
                         : "Use \(displayBiometricType.displayName) to unlock MovoCash quickly and securely. Your biometric data never leaves this device.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.xxl + 8)
                
                // Error (hidden once enrolled)
                if !enrollmentSucceeded, let err = errorMessage {
                    Text(err)
                        .textStyle(Typography.subtitle)
                        .foregroundStyle(Color.movo.danger)
                        .padding(.top, Spacing.lg)
                        .padding(.horizontal, Spacing.xxxl)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                VStack(spacing: Spacing.md) {
                    Button(action: {
                        Task { await enroll() }
                    }) {
                        Group {
                            if enrollmentSucceeded {
                                Label("Enrolled", systemImage: "checkmark")
                            } else if isEnrolling {
                                ProgressView()
                            } else {
                                Text("Enable \(displayBiometricType.displayName)")
                            }
                        }
                    }
                    .buttonStyle(MovoPrimaryButtonStyle())
                    .disabled(isEnrolling || enrollmentSucceeded)
                    .padding(.horizontal, Spacing.xxl)

                    // Skip — hidden once enrolled
                    if !enrollmentSucceeded {
                        Button(action: { onSkip() }) {
                            Text("Skip")
                        }
                        .buttonStyle(OutlineButtonStyle())
                        .padding(.horizontal, Spacing.xxl)
                    }
                }
                
                Spacer().frame(height: 24)
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
                onOpenSettings?()
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Skip", role: .cancel) { }
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

        // Fast path: this specific user has already enrolled biometrics on this device.
        // Uses a per-user Keychain flag so User B is not skipped because User A enrolled.
        // Covers two scenarios:
        //   (a) Passkey cancelled on a previous attempt — Face ID + RSA are done,
        //       only the passkey step is outstanding.
        //   (b) Login where biometrics were enrolled in a prior session but passkey
        //       never completed — jump straight to passkey without re-enrolling.
        let alreadyEnrolledForUser = await authVM.isBiometricEnrolledForCurrentUser()

        // Guard: per-user flag says enrolled but the Secure Enclave key is missing.
        // This happens after an app reinstall, a failed revoke, or any path that
        // deleted the key without clearing the flag. Clear the stale flag so the
        // full enrollment flow runs and creates a fresh key.
        if alreadyEnrolledForUser && !lockManager.isBiometricEnabled {
            await authVM.clearBiometricEnrollmentForCurrentUser()
        }

        // Fast path only when BOTH the per-user flag AND the Secure Enclave key exist.
        // If the key is missing the condition above cleared the flag, so this is skipped.
        if lockManager.isBiometricAvailable && alreadyEnrolledForUser && lockManager.isBiometricEnabled {
            isEnrolling = true
            defer { isEnrolling = false }
            let passkeySucceeded = await onEnable()
            if !passkeySucceeded {
                errorMessage = "Device registration failed. Please try again."
            }
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

        // 4. Persist per-user enrollment flag so this specific user is not asked
        //    to re-enroll on next login, and other users on the same device are
        //    not incorrectly treated as enrolled.
        await authVM.markBiometricEnrolled()
        
        // Show success confirmation on this screen before navigating forward.
        // Gives the user a clear signal that enrollment completed.
        enrollmentSucceeded = true
        isEnrolling = false
        try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 s

        let passkeySucceeded = await onEnable()
        if !passkeySucceeded {
            // Passkey was cancelled or failed — reset so the user can retry
            // without being stuck in the disabled "Enrolled" state.
            enrollmentSucceeded = false
            errorMessage = "Device registration failed. Please try again."
        }
    }
}


// MARK: - Face Scan View

struct FaceScanView: View {
    
    var enrollmentSucceeded: Bool
    
    var body: some View {
        ZStack {
            
            // Dotted Circle (lighter + tighter)
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                .foregroundColor(circleColor.opacity(0.4))
                .frame(width: 200, height: 200)
            
            // Corner Brackets (slightly bigger + rounded feel)
            CornerBrackets()
                .stroke(circleColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 140, height: 140)
            
            if enrollmentSucceeded {
                successView
            } else {
                scanningView
            }
        }
    }
}

// MARK: - Subviews

extension FaceScanView {
    
    private var scanningView: some View {
        VStack(spacing: 14) {
            
            // Eyes (smaller + better spacing)
            HStack(spacing: 18) {
                Circle()
                    .fill(Color.movo.textSecondary)
                    .frame(width: 5, height: 5)

                Circle()
                    .fill(Color.movo.textSecondary)
                    .frame(width: 5, height: 5)
            }
            
            // Scan Line (rounded ends like design)
            Capsule()
                .fill(Color.movo.accent)
                .frame(width: 80, height: 4)
            
            // Smile (better curve)
            SmileShape()
                .stroke(Color.movo.textSecondary, lineWidth: 2)
                .frame(width: 34, height: 16)
        }
    }
    
    private var successView: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(Color.movo.accent)
    }
    
    private var circleColor: Color {
        enrollmentSucceeded
        ? Color.movo.accent
        : Color.movo.accent.opacity(0.8)
    }
}

// MARK: - Shapes

struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 22
        
        // Top-left
        p.move(to: CGPoint(x: 0, y: l))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: l, y: 0))
        
        // Top-right
        p.move(to: CGPoint(x: rect.width - l, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: l))
        
        // Bottom-left
        p.move(to: CGPoint(x: 0, y: rect.height - l))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: l, y: rect.height))
        
        // Bottom-right
        p.move(to: CGPoint(x: rect.width - l, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - l))
        
        return p
    }
}


struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: rect.height * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.4),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        
        return path
    }
}
