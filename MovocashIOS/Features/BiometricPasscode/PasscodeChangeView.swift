//
//  PasscodeChangeView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

struct PasscodeChangeView: View {

    var onDismiss: () -> Void

    @StateObject private var vm: AppLockViewModel

    init(lockManager: AppLockManager, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: AppLockViewModel(lockManager: lockManager))
    }

    private let pinLength = AppLockViewModel.pinLength

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: stepIcon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                        Text(stepTitle)
                            .font(.title2.bold())
                        Text(stepSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.movo.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer().frame(height: 40)

                    // Dots or success badge
                    if vm.changeStep == .success {
                        successBadge
                    } else {
                        PINDotsView(filledCount: vm.pinInput.count, total: pinLength)
                            .modifier(ShakeModifier(trigger: vm.shouldShake))
                    }

                    // Status / error
                    Text(vm.changeStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(height: 24)
                        .padding(.top, 16)
                        .animation(.default, value: vm.changeStatusMessage)

                    Spacer().frame(height: 32)

                    // PIN pad or Done button
                    if vm.changeStep != .success {
                        PINPadView(
                            onDigit: { vm.handleChangeDigit($0) },
                            onDelete: { vm.deleteLastDigit() },
                            onBiometric: nil,
                            biometricIcon: ""
                        )
                        .padding(.horizontal, 24)
                    } else {
                        Button("Done", action: onDismiss)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .font(.headline)
                            .padding(.horizontal, 40)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Change Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.changeStep != .success {
                        Button("Cancel") {
                            vm.resetChangeFlow()
                            onDismiss()
                        }
                    }
                }
            }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Text helpers

    private var stepTitle: String {
        switch vm.changeStep {
        case .verifyOld:  return "Enter Current Passcode"
        case .enterNew:   return "Enter New Passcode"
        case .confirmNew: return "Confirm New Passcode"
        case .success:    return "Passcode Changed"
        }
    }

    private var stepSubtitle: String {
        switch vm.changeStep {
        case .verifyOld:  return "Confirm your identity before making changes"
        case .enterNew:   return "Choose a new 6-digit passcode"
        case .confirmNew: return "Re-enter your new passcode to confirm"
        case .success:    return "Your passcode has been updated"
        }
    }

    private var stepIcon: String {
        switch vm.changeStep {
        case .verifyOld, .enterNew, .confirmNew: return "lock.rotation"
        case .success:                           return "checkmark.shield.fill"
        }
    }

    private var successBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.4), value: vm.changeStep == .success)
    }
}
