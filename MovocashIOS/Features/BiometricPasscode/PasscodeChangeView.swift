//
//  PasscodeChangeView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

struct PasscodeChangeView: View {

    let lockManager: AppLockManager
    var onDismiss: () -> Void

    // 3-step flow
    enum ChangeStep { case verifyOld, enterNew, confirmNew, success }

    @State private var step: ChangeStep = .verifyOld
    @State private var pinInput:    String = ""
    @State private var oldPin:      String = ""
    @State private var newPin:      String = ""
    @State private var shouldShake: Bool   = false
    @State private var statusMessage: String = ""
    @State private var isLoading:   Bool   = false

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
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer().frame(height: 40)

                    // Dots or success badge
                    if step == .success {
                        successBadge
                    } else {
                        PINDotsView(filledCount: pinInput.count, total: pinLength)
                            .modifier(ShakeModifier(trigger: shouldShake))
                    }

                    // Status / error
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(height: 24)
                        .padding(.top, 16)
                        .animation(.default, value: statusMessage)

                    Spacer().frame(height: 32)

                    // PIN pad or Done button
                    if step != .success {
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
                    if step != .success {
                        Button("Cancel", action: onDismiss)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Input handling

    private func handleDigit(_ digit: String) {
        guard pinInput.count < pinLength else { return }
        pinInput.append(digit)
        if pinInput.count == pinLength {
            Task { await advance() }
        }
    }

    // MARK: - Step machine

    private func advance() async {
        let entered = pinInput

        switch step {

        // ── Step 1: verify current passcode ─────────────────────────────
        case .verifyOld:
            isLoading = true
            do {
                let ok = try lockManager.passcodeManager.verifyPasscode(entered)
                if ok {
                    oldPin = entered
                    clearInput()
                    statusMessage = ""
                    step = .enterNew
                } else {
                    shake(message: "Incorrect passcode. Try again.")
                }
            } catch {
                shake(message: error.localizedDescription)
            }
            isLoading = false

        // ── Step 2: enter new passcode ───────────────────────────────────
        case .enterNew:
            guard entered != oldPin else {
                shake(message: "New passcode must differ from current one.")
                return
            }
            newPin = entered
            clearInput()
            statusMessage = ""
            step = .confirmNew

        // ── Step 3: confirm new passcode ─────────────────────────────────
        case .confirmNew:
            guard entered == newPin else {
                shake(message: "Passcodes don't match. Start over.")
                clearInput()
                newPin = ""
                step = .enterNew
                return
            }
            isLoading = true
            do {
                try await lockManager.changePasscode(old: oldPin, new: newPin)
                step = .success
                statusMessage = ""
            } catch {
                shake(message: error.localizedDescription)
                step = .verifyOld
                oldPin = ""
                newPin = ""
            }
            isLoading = false

        case .success:
            break
        }
    }

    // MARK: - Helpers

    private func clearInput() { pinInput = "" }

    private func shake(message: String) {
        statusMessage = message
        clearInput()
        shouldShake = false
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            shouldShake = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            shouldShake = false
        }
    }

    // MARK: - Text helpers

    private var stepTitle: String {
        switch step {
        case .verifyOld:   return "Enter Current Passcode"
        case .enterNew:    return "Enter New Passcode"
        case .confirmNew:  return "Confirm New Passcode"
        case .success:     return "Passcode Changed"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .verifyOld:   return "Confirm your identity before making changes"
        case .enterNew:    return "Choose a new 6-digit passcode"
        case .confirmNew:  return "Re-enter your new passcode to confirm"
        case .success:     return "Your passcode has been updated"
        }
    }

    private var stepIcon: String {
        switch step {
        case .verifyOld, .enterNew, .confirmNew: return "lock.rotation"
        case .success:                           return "checkmark.shield.fill"
        }
    }

    private var successBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.4), value: step)
    }
}
