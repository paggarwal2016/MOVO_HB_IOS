//
//  PasscodeSetupView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

struct PasscodeSetupView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @ObservedObject var vm: AppLockViewModel
    @EnvironmentObject var sessionManager: SessionManager

    var onSuccess: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.movo.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Back button — only on enterNew step
                if vm.setupStep == .enterNew {
                    HStack {
                        BackButton {
                            if let cancel = onCancel {
                                cancel()
                            } else {
                                lockManager.logout()
                                Task {
                                    await sessionManager.logout(appState: appState)
                                    appState.flow = .choice
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }

                Spacer()

                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: stepIcon)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.movo.textPrimary)
                        .accessibilityHidden(true)
                    Text(stepTitle)
                        .textStyle(Typography.sectionTitle)
                    Text(stepSubtitle)
                        .textStyle(Typography.body)
                        .foregroundStyle(Color.movo.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxxl)
                }

                Spacer().frame(height: 40)

                // Dots or success badge
                if vm.setupStep == .success {
                    successBadge
                } else {
                    PINDotsView(
                        filledCount: vm.pinInput.count,
                        total: AppLockViewModel.pinLength
                    )
                    .modifier(ShakeModifier(trigger: vm.shouldShake))
                }

                // Status / error
                Text(vm.statusMessage)
                    .textStyle(Typography.caption)
                    .foregroundStyle(Color.movo.danger)
                    .frame(height: 24)
                    .padding(.top, Spacing.lg)

                Spacer().frame(height: 32)

                // PIN pad (hidden on success)
                if vm.setupStep != .success {
                    PINPadView(
                        onDigit: handleDigit,
                        onDelete: vm.deleteLastDigit,
                        onBiometric: nil,
                        biometricIcon: ""
                    )
                    .padding(.horizontal, Spacing.xxl)
                }

                Spacer()
            }
        }
        .onAppear { vm.resetSetupFlow() }
        // Auto-advance the moment setupStep becomes .success
        .onChange(of: vm.setupStep) { step in
            if step == .success {
                // Brief pause so the success badge is visible before transition
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                    onSuccess()
                }
            }
        }
    }

    // MARK: - Digit input

    /// Only append — AppLockViewModel.appendDigit() auto-submits at 6 digits.
    /// Never call submitSetupPin here to avoid double-submission.
    private func handleDigit(_ digit: String) {
        vm.appendDigit(digit)
    }

    // MARK: - Sub-views

    private var successBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(Color.movo.success)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.4), value: vm.setupStep)
    }

    // MARK: - Text helpers

    private var stepTitle: String {
        switch vm.setupStep {
        case .enterNew:   return "Create Passcode"
        case .confirmNew: return "Confirm Passcode"
        case .success:    return "Passcode Set!"
        }
    }

    private var stepSubtitle: String {
        switch vm.setupStep {
        case .enterNew:   return "Enter a 6-digit passcode"
        case .confirmNew: return "Re-enter your passcode to confirm"
        case .success:    return "Your account is now protected"
        }
    }

    private var stepIcon: String {
        switch vm.setupStep {
        case .enterNew, .confirmNew: return "lock.fill"
        case .success:               return "checkmark.shield.fill"
        }
    }
}
