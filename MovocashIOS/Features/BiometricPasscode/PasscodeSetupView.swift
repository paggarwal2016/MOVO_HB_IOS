//
//  PasscodeSetupView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

struct PasscodeSetupView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: AppLockViewModel
    @EnvironmentObject var sessionManager: SessionManager

    var onSuccess: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {

                // Back button — only on enterNew step
                if vm.setupStep == .enterNew {
                    HStack {
                        BackButton { //TODO: Future Implementation will check below code logic
                            AppContainer.shared.lockManager.logout()
                            Task {
                                await sessionManager.logout(appState: appState)
                                appState.flow = .loginPhone
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }

                Spacer()

                // Header
                VStack(spacing: 8) {
                    Image(systemName: stepIcon)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                    Text(stepTitle)
                        .font(.title2.bold())
                    Text(stepSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
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
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(height: 24)
                    .padding(.top, 16)

                Spacer().frame(height: 32)

                // PIN pad (hidden on success)
                if vm.setupStep != .success {
                    PINPadView(
                        onDigit: handleDigit,
                        onDelete: vm.deleteLastDigit,
                        onBiometric: nil,
                        biometricIcon: ""
                    )
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
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
            .foregroundStyle(.green)
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
