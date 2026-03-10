//
//  AppLockViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 10/03/26.
//

import SwiftUI
import Combine

@MainActor
final class AppLockViewModel: ObservableObject {

    // MARK: - Published UI state

    @Published var pinInput: String = ""
    @Published var isAlphanumeric: Bool = false
    @Published var alphanumericInput: String = ""
    @Published var shouldShake: Bool = false
    @Published var statusMessage: String = ""
    @Published var isLoading: Bool = false

    // Setup flow
    @Published var setupStep: SetupStep = .enterNew
    @Published var firstEntryPin: String = ""

    enum SetupStep { case enterNew, confirmNew, success }

    // MARK: - Mode

    /// true  → appendDigit auto-submits into the SETUP flow
    /// false → appendDigit auto-submits into the UNLOCK flow (default)
    var isSetupMode: Bool = false

    // MARK: - Config

    static let pinLength = 6

    // MARK: - Dependencies

    private let lockManager: AppLockManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(lockManager: AppLockManager) {
        self.lockManager = lockManager

        lockManager.$lockoutMessage
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .assign(to: &$statusMessage)
    }

    // MARK: - PIN pad input

    func appendDigit(_ digit: String) {
        guard pinInput.count < Self.pinLength else { return }
        pinInput.append(contentsOf: digit)

        guard pinInput.count == Self.pinLength else { return }

        if isSetupMode {
            // Capture before submitSetupPin clears it
            let pin = pinInput
            submitSetupPin(pin)
        } else {
            Task { await submitPIN() }
        }
    }

    func deleteLastDigit() {
        guard !pinInput.isEmpty else { return }
        pinInput.removeLast()
    }

    func clearInput() {
        pinInput = ""
        alphanumericInput = ""
    }

    // MARK: - Unlock submit

    func submitPIN() async {
        let pin = isAlphanumeric ? alphanumericInput : pinInput
        guard !pin.isEmpty else { return }
        isLoading = true
        let success = await lockManager.unlockWithPasscode(pin)
        isLoading = false
        if !success {
            triggerShake()
            clearInput()
        }
    }

    func submitBiometric() async {
        await lockManager.unlockWithBiometric()
    }

    // MARK: - Setup flow

    func submitSetupPin(_ pin: String) {
        switch setupStep {
        case .enterNew:
            guard pin.count == Self.pinLength else {
                statusMessage = "PIN must be 6 digits"
                return
            }
            firstEntryPin = pin
            setupStep = .confirmNew
            clearInput()
            statusMessage = ""

        case .confirmNew:
            guard pin == firstEntryPin else {
                statusMessage = "PINs do not match. Try again."
                triggerShake()
                clearInput()
                setupStep = .enterNew
                firstEntryPin = ""
                return
            }
            Task { await confirmSetup(pin: pin) }

        case .success:
            break
        }
    }

    private func confirmSetup(pin: String) async {
        isLoading = true
        do {
            try await lockManager.setupPasscode(pin)
            setupStep = .success          // triggers .onChange in PasscodeSetupView
            statusMessage = ""
        } catch {
            statusMessage = error.localizedDescription
            triggerShake()
            clearInput()
            setupStep = .enterNew
            firstEntryPin = ""
        }
        isLoading = false
    }

    // MARK: - Helpers

    func toggleInputMode() {
        isAlphanumeric.toggle()
        clearInput()
        statusMessage = ""
    }

    private func triggerShake() {
        shouldShake = false
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            shouldShake = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            shouldShake = false
        }
    }

    // MARK: - Computed

    var biometricLabel: String { lockManager.biometricType.displayName }
    var biometricIcon: String  { lockManager.biometricType.systemImageName }
    var showBiometric: Bool    { lockManager.isBiometricAvailable && lockManager.isPasscodeSet }
}
