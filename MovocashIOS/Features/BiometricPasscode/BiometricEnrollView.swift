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
    /// Called when the user acknowledges a technical enrollment failure, or a
    /// "can't enroll" situation (biometrics not set up / permission denied), by
    /// tapping the alert's OK/Cancel. Login & onboarding use this to redirect the
    /// user (e.g. log out → Choice screen). Left nil in Settings/Profile, where a
    /// failure simply stays on screen.
    var onEnrollmentFailedExit: (() -> Void)? = nil
    /// Authenticate-mode only. Called when biometric auth cannot structurally succeed
    /// (the local RSA key is missing/stale, e.g. after a reinstall). The caller clears
    /// the stale enrollment state and routes to enrollment so the user re-enrolls
    /// (new key + passkey) instead of looping on an impossible authentication.
    var onNeedsReenrollment: (() -> Void)? = nil
    /// Screen mode. `.enroll` sets up biometrics (first login / onboarding);
    /// `.authenticate` verifies an already-enrolled user (repeat login) via the RSA
    /// biometric login — reusing this same screen so the flow stays visually consistent.
    var mode: Mode = .enroll
    /// Authenticate-mode only — performs the biometric scan (RSA login) and returns
    /// the outcome so this view can apply the retry limit. Ignored in enroll mode.
    var authenticate: (() async -> AuthViewModel.BiometricAuthOutcome)? = nil
    /// Max real authentication failures before giving up (authenticate mode).
    /// User-cancels do not count.
    var maxAuthAttempts: Int = 3

    enum Mode { case enroll, authenticate }

    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var isEnrolling = false
    @State private var enrollmentSucceeded = false
    @State private var errorMessage: String? = nil
    @State private var showSettingsAlert = false
    @State private var wentToSettings = false
    @State private var authAttempts = 0

    // Use hardware type so the icon/name is correct even when not yet OS-enrolled
    private var displayBiometricType: BiometricType {
        lockManager.isBiometricAvailable
        ? lockManager.biometricType
        : lockManager.hardwareBiometricType
    }

    // MARK: - Mode-aware copy

    private var titleText: String {
        switch mode {
        case .enroll:
            return enrollmentSucceeded
                ? "\(displayBiometricType.displayName) Enabled"
                : "Enable \(displayBiometricType.displayName)"
        case .authenticate:
            return enrollmentSucceeded
                ? "\(displayBiometricType.displayName) Verified"
                : "Confirm \(displayBiometricType.displayName)"
        }
    }

    private var descriptionText: String {
        switch mode {
        case .enroll:
            return enrollmentSucceeded
                ? "\(displayBiometricType.displayName) is now set up. You can use it to unlock MovoCash quickly and securely."
                : "Use \(displayBiometricType.displayName) to unlock MovoCash quickly and securely. Your biometric data never leaves this device."
        case .authenticate:
            return enrollmentSucceeded
                ? "You're verified. Taking you to your account…"
                : "Confirm your identity with \(displayBiometricType.displayName) to continue."
        }
    }

    private var primaryButtonTitle: String {
        mode == .enroll
        ? "Enable \(displayBiometricType.displayName)"
        : "Unlock with \(displayBiometricType.displayName)"
    }

    private var primaryButtonSuccessLabel: String {
        mode == .enroll ? "Enrolled" : "Verified"
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
                    
                    Text(titleText)
                    .textStyle(Typography.balance)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)

                    Text(descriptionText)
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
                        Task { await primaryAction() }
                    }) {
                        Group {
                            if enrollmentSucceeded {
                                Label(primaryButtonSuccessLabel, systemImage: "checkmark")
                            } else if isEnrolling {
                                ProgressView()
                            } else {
                                Text(primaryButtonTitle)
                            }
                        }
                    }
                    .buttonStyle(MovoPrimaryButtonStyle())
                    .disabled(isEnrolling || enrollmentSucceeded)
                    .padding(.horizontal, Spacing.xxl)

                    // Skip — hidden (kept for reference). Biometric enrollment is
                    // required, so the Skip button is not shown to the user.
//                    if !enrollmentSucceeded {
//                        Button(action: { onSkip() }) {
//                            Text("Skip")
//                        }
//                        .buttonStyle(OutlineButtonStyle())
//                        .padding(.horizontal, Spacing.xxl)
//                    }
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
            // In login/onboarding (exit callback provided) the user can't proceed
            // without enrolling, so acknowledging routes them out (e.g. log out → Choice).
            // In Settings/Profile it simply dismisses.
            if onEnrollmentFailedExit != nil {
                Button("Cancel", role: .cancel) { onEnrollmentFailedExit?() }
            } else {
                Button("Skip", role: .cancel) { }
            }
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
            // Mode-aware: retry enrollment or authentication depending on the screen mode.
            Task { await primaryAction() }
        }
    }
    
    // MARK: - Enroll

    /// Present a failure. Settings/Profile (no exit callback) keep the inline error
    /// only. Login / onboarding surface the app's custom error alert (AlertManager);
    /// tapping OK hands off to `onEnrollmentFailedExit` (log out → Choice screen).
    private func failEnrollment(_ message: String) {
        errorMessage = message

        // Settings/Profile (no exit callback) keep the inline error only — no alert.
        guard let exit = onEnrollmentFailedExit else { return }

        // Login / onboarding: custom error alert; OK → redirect (log out → Choice).
        AlertManager.shared.showError(message, onDismiss: exit)
    }

    /// Runs the primary action for the current mode (button tap / alert "Try Again").
    private func primaryAction() async {
        switch mode {
        case .enroll:       await enroll()
        case .authenticate: await runAuthenticate()
        }
    }

    // MARK: - Authenticate (repeat login)

    /// Authenticate-mode flow: run the biometric scan (RSA login) and apply the
    /// retry limit. Success → `onEnable()` (passkey check + navigate to dashboard).
    /// Each incomplete attempt (failed scan OR backing out of the system Face ID
    /// sheet) counts toward `maxAuthAttempts`. Intermediate failures show NO app alert
    /// (iOS already presented its own Face ID sheet) — just an inline hint; the user
    /// retries via the button. The single app alert is the final "too many attempts"
    /// one, whose OK hands off to `onEnrollmentFailedExit` (log out → Choice).
    private func runAuthenticate() async {
        guard !enrollmentSucceeded, !isEnrolling, let authenticate else { return }
        isEnrolling = true
        defer { isEnrolling = false }

        // Guard: biometrics must be usable before attempting the scan. If the app's
        // permission was revoked, or the hardware is unavailable / not set up in iOS
        // Settings, show the Settings alert instead of a doomed scan (same as enroll).
        if lockManager.isBiometricPermissionDenied {
            showSettingsAlert = true
            return
        }
        if !lockManager.isBiometricAvailable {
            showSettingsAlert = true
            return
        }

        errorMessage = nil

        switch await authenticate() {
        case .success:
            authAttempts = 0
            enrollmentSucceeded = true
            _ = await onEnable()
        case .needsEnrollment:
            // Structural failure (missing/stale key) — re-enroll instead of retrying,
            // otherwise auth would fail forever.
            onNeedsReenrollment?()
        case .failed, .cancelled:
            // Count every incomplete attempt. iOS owns the in-sheet "Try Again" retries
            // for a failed scan, so the app regains control once per app-level attempt
            // (a failed scan → .failed; backing out of the system sheet → .cancelled).
            authAttempts += 1
            if authAttempts >= maxAuthAttempts {
                failEnrollment("It looks like something is incorrect. Please confirm your credentials and contact with our support team 855-439-6686")
            } else {
                let remaining = maxAuthAttempts - authAttempts
                errorMessage = "\(displayBiometricType.displayName) not verified. \(remaining) attempt\(remaining == 1 ? "" : "s") left."
            }
        }
    }

    private func enroll() async {
        guard !enrollmentSucceeded, !isEnrolling else { return }
        isEnrolling = true
        defer { isEnrolling = false }

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
            let passkeySucceeded = await onEnable()
            if !passkeySucceeded {
                errorMessage = "Device registration failed. Please try again."
            }
            return
        }

        errorMessage = nil
        
        // 1. Verify biometric works right now (shows system prompt)
        do {
            try await lockManager.biometricManager.evaluate(
                reason: "Confirm biometric to enable quick unlock"
            )
        } catch let err as BiometricError {
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
            errorMessage = error.localizedDescription
            return
        }

        // 2. Store Secure Enclave key
        do {
            try lockManager.enrollBiometrics()
        } catch {
            failEnrollment(error.localizedDescription)
            return
        }
        
        do {
            try await authVM.enrollRSA()
        } catch let enrollError {
            do {
                try lockManager.revokeBiometrics()
            } catch {
                failEnrollment("Enrollment failed and could not be fully rolled back. Please log out and try again.")
                return
            }
            if enrollError.shouldShowUserFacingToast {
                failEnrollment("Enrollment incomplete. \(enrollError.localizedDescription)")
            }
            return
        }

        // 4. Persist per-user enrollment flag so this specific user is not asked
        //    to re-enroll on next login, and other users on the same device are
        //    not incorrectly treated as enrolled.
        await authVM.markBiometricEnrolled()
        
        enrollmentSucceeded = true
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
