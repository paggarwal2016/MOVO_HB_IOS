//
//  AppLockViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
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

    private var shakeTask: Task<Void, Never>?
    private var submitTask: Task<Void, Never>?

    // MARK: - Mode

    /// true  → appendDigit auto-submits into the SETUP flow
    /// false → appendDigit auto-submits into the UNLOCK flow (default)
    var isSetupMode: Bool = false

    // MARK: - Change Passcode backing store

    enum ChangeStep { case verifyOld, enterNew, confirmNew, success }

    @Published var _changeStep: ChangeStep = .verifyOld
    @Published var _changeStatusMessage: String = ""
    var _changeOldPin: String = ""
    var _changeNewPin: String = ""

    // MARK: - Config

    static let pinLength = 6

    // MARK: - Dependencies

    private let lockManager: AppLockManager

    // MARK: - Init

    init(lockManager: AppLockManager) {
        self.lockManager = lockManager

        lockManager.$lockoutMessage
            .map { $0 ?? "" }
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
            guard !isLoading else { return }
            submitTask?.cancel()
            submitTask = Task { await submitPIN() }
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

    /// Resets all setup-flow state. Call when PasscodeSetupView appears.
    func resetSetupFlow() {
        setupStep     = .enterNew
        firstEntryPin = ""
        statusMessage = ""
        shouldShake   = false
        clearInput()
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
            submitTask?.cancel()
            submitTask = Task { await confirmSetup(pin: pin) }

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
        shakeTask?.cancel()
        shouldShake = false
        shakeTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            shouldShake = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            shouldShake = false
        }
    }

    deinit {
        shakeTask?.cancel()
        submitTask?.cancel()
    }

    // MARK: - Computed

    var biometricLabel: String { lockManager.biometricType.displayName }
    var biometricIcon: String  { lockManager.biometricType.systemImageName }
    var showBiometric: Bool    { lockManager.isBiometricAvailable && lockManager.isPasscodeSet }
}


// MARK: - Change Passcode Flow

extension AppLockViewModel {

    // MARK: - Published Change State

    var changeStep: ChangeStep {
        get { _changeStep }
        set { _changeStep = newValue }
    }
    var changeStatusMessage: String {
        get { _changeStatusMessage }
        set { _changeStatusMessage = newValue }
    }

    // MARK: - Digit Input

    func handleChangeDigit(_ digit: String) {
        guard pinInput.count < Self.pinLength else { return }
        pinInput.append(contentsOf: digit)
        guard pinInput.count == Self.pinLength else { return }
        submitTask?.cancel()
        submitTask = Task { await advanceChangePasscode() }
    }

    // MARK: - Step Machine

    func advanceChangePasscode() async {
        let entered = pinInput

        switch _changeStep {

        case .verifyOld:
            isLoading = true
            do {
                let ok = try lockManager.passcodeManager.verifyPasscode(entered)
                if ok {
                    _changeOldPin = entered
                    clearInput()
                    _changeStatusMessage = ""
                    _changeStep = .enterNew
                } else {
                    triggerChangeShake(message: "Incorrect passcode. Try again.")
                }
            } catch {
                triggerChangeShake(message: error.localizedDescription)
            }
            isLoading = false

        case .enterNew:
            guard entered != _changeOldPin else {
                triggerChangeShake(message: "New passcode must differ from current one.")
                return
            }
            _changeNewPin = entered
            clearInput()
            _changeStatusMessage = ""
            _changeStep = .confirmNew

        case .confirmNew:
            guard entered == _changeNewPin else {
                triggerChangeShake(message: "Passcodes don't match. Start over.")
                clearInput()
                _changeNewPin = ""
                _changeStep = .enterNew
                return
            }
            isLoading = true
            do {
                try await lockManager.changePasscode(old: _changeOldPin, new: _changeNewPin)
                _changeStep = .success
                _changeStatusMessage = ""
            } catch {
                triggerChangeShake(message: error.localizedDescription)
                _changeStep = .verifyOld
                _changeOldPin = ""
                _changeNewPin = ""
            }
            isLoading = false

        case .success:
            break
        }
    }

    func resetChangeFlow() {
        _changeStep = .verifyOld
        _changeStatusMessage = ""
        _changeOldPin = ""
        _changeNewPin = ""
        clearInput()
        shakeTask?.cancel()
    }

    // MARK: - Private helpers

    private func triggerChangeShake(message: String) {
        _changeStatusMessage = message
        clearInput()
        triggerShake()
    }
}
