//
//  SecuritySettingsView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

struct SecuritySettingsView: View {

    @ObservedObject var lockManager: AppLockManager
    @EnvironmentObject private var authVM: AuthViewModel

    // Sheet routing
    @State private var route: Route? = nil

    // Inline confirmation / alert state
    @State private var showDisableBiometricAlert = false
    @State private var showRemovePasscodeAlert   = false

    enum Route: Identifiable {
        case changePasscode
        case setupPasscode
        case enrollBiometric
        case removePasscodeConfirm  // PIN challenge before remove

        var id: Int { hashValue }
    }

    var body: some View {
        List {
            //passcodeSection
            biometricSection
            activitySection
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        // Error banner
        .safeAreaInset(edge: .top) {
            if let msg = lockManager.revocationError {
                errorBanner(msg)
            }
        }
        // Sheet routing
        .sheet(item: $route) { destination in
            switch destination {

            case .changePasscode:
                PasscodeChangeView(lockManager: lockManager) {
                    route = nil
                }

            case .setupPasscode:
                PasscodeSetupView(
                    vm: AppLockViewModel(lockManager: lockManager),
                    onSuccess: { route = nil },
                    onCancel:  { route = nil }
                )

            case .enrollBiometric:
                BiometricEnrollView(
                    lockManager: lockManager,
                    onEnable: { route = nil; return true },
                    onSkip:   { route = nil }
                )

            case .removePasscodeConfirm:
                // Re-auth challenge before removing passcode
                RemovePasscodeConfirmView(lockManager: lockManager) {
                    route = nil
                }
            }
        }
        // Disable biometric confirmation
        .alert("Disable \(lockManager.biometricType.displayName)?", isPresented: $showDisableBiometricAlert) {
            Button("Disable", role: .destructive) {
                lockManager.revokeBiometricSafely()
                // Clear the per-user Keychain enrollment flag so the next login
                // correctly re-prompts this user to re-enroll biometrics.
                Task { await authVM.clearBiometricEnrollmentForCurrentUser() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll need your passcode to unlock MovoCash.")
        }
    }

    // MARK: - Passcode section

    private var passcodeSection: some View {
        Section {
            if lockManager.isPasscodeSet {
                // Change passcode row
                Button {
                    route = .changePasscode
                } label: {
                    settingsRow(
                        icon: "lock.rotation",
                        iconColor: .blue,
                        title: "Change Passcode"
                    )
                }

                // Remove passcode row
                Button(role: .destructive) {
                    route = .removePasscodeConfirm
                } label: {
                    settingsRow(
                        icon: "lock.slash",
                        iconColor: .red,
                        title: "Remove Passcode"
                    )
                    .foregroundStyle(.red)
                }
            } else {
                Button {
                    route = .setupPasscode
                } label: {
                    settingsRow(
                        icon: "lock.fill",
                        iconColor: .green,
                        title: "Set Up Passcode"
                    )
                }
            }
        } header: {
            Text("Passcode")
        } footer: {
            Text(lockManager.isPasscodeSet
                 ? "A 6-digit passcode protects your account."
                 : "Set a passcode to protect your account and enable biometrics.")
        }
    }

    // MARK: - Biometric section

    private var effectiveBiometricType: BiometricType {
        lockManager.isBiometricAvailable
            ? lockManager.biometricType
            : lockManager.hardwareBiometricType
    }

    @ViewBuilder
    private var biometricSection: some View {
        let bioType = effectiveBiometricType
        if lockManager.isBiometricAvailable || lockManager.isBiometricHardwarePresent {
            Section {
                if lockManager.isBiometricEnabled {
                    // Toggle off
                    Button {
                        showDisableBiometricAlert = true
                    } label: {
                        settingsRow(
                            icon: bioType.systemImageName,
                            iconColor: .orange,
                            title: "Disable \(bioType.displayName)"
                        )
                        .foregroundStyle(.orange)
                    }
                } else if lockManager.isBiometricPermissionDenied {
                    // App permission revoked in iOS Settings → Privacy → Face ID / Touch ID
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        settingsRow(
                            icon: bioType.systemImageName,
                            iconColor: .gray,
                            title: "Enable \(bioType.displayName) Access"
                        )
                    }
                } else if !lockManager.isBiometricAvailable && lockManager.isBiometricHardwarePresent {
                    // Hardware present but not configured in iOS Settings
                    Button {
                        guard lockManager.isPasscodeSet else {
                            lockManager.showTemporaryError("Set a passcode first to enable biometrics.")
                            return
                        }
                        route = .enrollBiometric
                    } label: {
                        settingsRow(
                            icon: bioType.systemImageName,
                            iconColor: .blue,
                            title: "Set Up \(bioType.displayName)"
                        )
                    }
                } else {
                    // Toggle on
                    Button {
                        guard lockManager.isPasscodeSet else {
                            lockManager.showTemporaryError("Set a passcode first to enable biometrics.")
                            return
                        }
                        route = .enrollBiometric
                    } label: {
                        settingsRow(
                            icon: bioType.systemImageName,
                            iconColor: .blue,
                            title: "Enable \(bioType.displayName)"
                        )
                    }
                }
            } header: {
                Text("Biometrics")
            } footer: {
                if lockManager.isBiometricEnabled {
                    Text("\(bioType.displayName) is active for quick unlock.")
                } else if lockManager.isBiometricPermissionDenied {
                    Text("MovoCash doesn't have permission to use \(bioType.displayName). Tap above to enable it in iOS Settings.")
                } else if !lockManager.isBiometricAvailable && lockManager.isBiometricHardwarePresent {
                    Text("\(bioType.displayName) isn't configured in iOS Settings. Tap above to set it up.")
                } else {
                    Text("Use \(bioType.displayName) instead of typing your passcode each time.")
                }
            }
        }
    }

    // MARK: - Activity section (info only)

    private var activitySection: some View {
        Section {
            settingsRow(
                icon: "clock.arrow.2.circlepath",
                iconColor: .gray,
                title: "Auto-lock",
                detail: "After 30 seconds"
            )
            settingsRow(
                icon: "exclamationmark.shield",
                iconColor: .gray,
                title: "Failed Attempts",
                detail: "\(lockManager.failedAttempts) / \(lockManager.maxPasscodeAttempts)"
            )
        } header: {
            Text("Activity")
        }
    }

    // MARK: - Helpers


    // MARK: - Reusable row

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(Color.movo.textSecondary)
                    .font(.subheadline)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.red.gradient)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(), value: lockManager.revocationError)
    }
}

// MARK: - Remove Passcode Confirm (PIN re-auth gate)

/// Presents PIN pad, verifies current passcode, then removes everything.
struct RemovePasscodeConfirmView: View {

    let lockManager: AppLockManager
    var onDismiss: () -> Void

    @State private var pinInput    = ""
    @State private var shouldShake = false
    @State private var statusMessage = ""
    @State private var isLoading   = false

    private let pinLength = AppLockViewModel.pinLength

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "lock.slash.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.red)
                        Text("Remove Passcode")
                            .font(.title2.bold())
                        Text("Enter your current passcode to confirm removal.")
                            .font(.subheadline)
                            .foregroundStyle(Color.movo.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer().frame(height: 40)
                    PINDotsView(filledCount: pinInput.count, total: pinLength)
                        .modifier(ShakeModifier(trigger: shouldShake))
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(height: 24)
                        .padding(.top, 16)
                    Spacer().frame(height: 32)
                    PINPadView(
                        onDigit: handleDigit,
                        onDelete: {
                            guard !pinInput.isEmpty else { return }
                            pinInput.removeLast()
                        },
                        onBiometric: nil,
                        biometricIcon: ""
                    )
                    .padding(.horizontal, 24)
                    Spacer()
                }
            }
            .navigationTitle("Confirm Removal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onDismiss)
                }
            }
            .overlay {
                if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(.ultraThinMaterial) }
            }
        }
    }

    private func handleDigit(_ d: String) {
        guard pinInput.count < pinLength else { return }
        pinInput.append(d)
        if pinInput.count == pinLength { Task { await confirm() } }
    }

    private func confirm() async {
        isLoading = true
        do {
            try await lockManager.removePasscode(confirmedWith: pinInput)
            onDismiss()
        } catch {
            statusMessage = "Incorrect passcode."
            pinInput = ""
            shouldShake = false
            try? await Task.sleep(nanoseconds: 50_000_000)
            shouldShake = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            shouldShake = false
        }
        isLoading = false
    }
}

