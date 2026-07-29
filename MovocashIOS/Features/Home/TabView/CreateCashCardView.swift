//
//  CreateCashCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 21/04/26.
//

import SwiftUI

struct CreateCashCardView: View {

    // MARK: - Dependencies & Callbacks

    let vm: VCardViewModel

    var plaidVM: PlaidAchViewModel? = nil
    
    let primaryAccountId: Int

    var title: String = "Set digital cash card PIN"
    
    var mode: Mode = .create
    
    var createUserAction: String = "VCARD-CREATION"
    
    var showsNicknameField: Bool = true
    
    var nicknameFieldLabel: String = "CARD NAME"
    
    var fixedNickname: String? = nil
    
    var isNicknameEditable: Bool = true
    
    let onClose: () -> Void
    
    var onCreated: ((VCardListResponse) -> Void)? = nil
    
    var onActivated: (() -> Void)? = nil

    var onActivationRequiresSupport: (() -> Void)? = nil

    enum Mode { case create, activate }

    // MARK: - State

    @State private var nickname = ""
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showPin = false
    @State private var showConfirmPin = false
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    fileprivate enum Field { case nickname, pin, confirmPin }

    private var pinsMatch: Bool { pin == confirmPin }
    private var pinMismatch: Bool { confirmPin.count == 4 && !pinsMatch }
    private var isPinWeak: Bool { pin.count == 4 && Self.weakPins.contains(pin) }

    /// PINs that are too easily guessed — block submission.
    private static let weakPins: Set<String> = [
        "0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
        "0123", "1234", "2345", "3456", "4567", "5678", "6789", "7890",
        "9876", "8765", "7654", "6543", "5432", "4321", "3210", "0987",
        "1212", "2121", "0101", "1010", "1122", "2211", "0011", "1100",
        "2580", "1357", "1470", "2469",
    ]

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        pin.count == 4 && pin.allSatisfy(\.isNumber) && !isPinWeak &&
        confirmPin.count == 4 && pinsMatch
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            CustomSheetHeader(
                title: title,
                // KYCSuccessView's .activate entry hides the subtitle and close button.
                subtitle: "",
                systemImage: "creditcard.fill",
                iconTint: Color.movo.accent,
                iconBackground: Color.movo.accentTint,
                showsCloseButton: mode != .activate,
                horizontalPadding: Spacing.xl,
                closeAction: onClose
            )
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(spacing: Spacing.xl) {
                            // KYCSuccessView's .activate entry shows PIN entry only.
                            if mode != .activate {
                                nicknameField
                            }
                            pinSection
                            confirmPinSection
                        }
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.xl)

                        Spacer(minLength: Spacing.xl)

                        actionButtons
                            .padding(.horizontal, Spacing.xl)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xxxl)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Color.movo.surface.ignoresSafeArea())
        .onAppear {
            if let fixedNickname { nickname = fixedNickname }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = (showsNicknameField && isNicknameEditable) ? .nickname : .pin
            }
        }
        .onDisappear {
            SpinnerView.hideFullScreen()
        }
        .globalAlert()
    }
}

// MARK: - Fields

private extension CreateCashCardView {

    var nicknameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            fieldLabel(nicknameFieldLabel)
            TextField(
                "",
                text: $nickname,
                prompt: Text("e.g. My Cash Card").foregroundColor(Color.movo.textDisabled)
            )
            .textStyle(Typography.body)
            .foregroundStyle(Color.movo.textPrimary)
            .tint(Color.movo.accent)
            .submitLabel(.next)
            .onSubmit { focusedField = .pin }
            .focused($focusedField, equals: .nickname)
            .disabled(isLoading || !isNicknameEditable)
            .padding(.horizontal, Spacing.md)
            .frame(height: 48)
            .background(Color.movo.elevated, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card).stroke(
                    focusedField == .nickname ? Color.movo.accentBorder : Color.movo.borderStrong,
                    lineWidth: focusedField == .nickname ? Stroke.medium : Stroke.thin
                )
            )
            .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: focusedField == .nickname)
        }
    }

    var pinSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                fieldLabel("SET YOUR PIN")
                Spacer()
                eyeToggle(isOn: $showPin)
            }
            PinBoxRow(
                pin: $pin,
                isVisible: showPin,
                isFocused: focusedField == .pin,
                isError: isPinWeak,
                isLoading: isLoading,
                focusField: { focusedField = .pin },
                field: .pin,
                focusedField: $focusedField,
                onComplete: { focusedField = .confirmPin }
            )
            if isPinWeak {
                errorLabel("PIN is too simple. Choose something less predictable.")
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: isPinWeak)
    }

    var confirmPinSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                fieldLabel("CONFIRM PIN")
                Spacer()
                eyeToggle(isOn: $showConfirmPin)
            }
            PinBoxRow(
                pin: $confirmPin,
                isVisible: showConfirmPin,
                isFocused: focusedField == .confirmPin,
                isError: pinMismatch,
                isLoading: isLoading,
                focusField: { focusedField = .confirmPin },
                field: .confirmPin,
                focusedField: $focusedField,
                onComplete: { focusedField = nil }
            )
            if pinMismatch {
                errorLabel("PINs do not match")
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: pinMismatch)
    }

    var actionButtons: some View {
        Button(action: submit) {
            Text("LET'S MOVO!")
                .tracking(1.5)
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!isValid || isLoading)
        .opacity(isValid && !isLoading ? 1.0 : 0.4)
    }

    // MARK: - Small helpers

    func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.eyebrow)
            .foregroundStyle(Color.movo.textSecondary)
    }

    func errorLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.caption)
            .foregroundStyle(Color.movo.danger)
            .padding(.leading, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    func eyeToggle(isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            Image(systemName: isOn.wrappedValue ? "eye.slash" : "eye")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.movo.textTertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Actions

private extension CreateCashCardView {

    func submit() {
        guard isValid else { return }
        focusedField = nil
        isLoading = true
        dismissKeyboardForcefully()
        SpinnerView.showFullScreen()
        switch mode {
        case .create:
            let request = CreateVCardRequest(
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                pin: pin,
                primaryAccountId: primaryAccountId,
                userAction: createUserAction
            )
            Task {
                let card = try? await vm.createVCard(request: request)
                await MainActor.run {
                    isLoading = false
                    SpinnerView.hideFullScreen()
                    if let card { onCreated?(card) }
                }
            }
        case .activate:
            Task {
                await plaidVM?.activateVirtualCard(
                    pin: pin,
                    accountId: primaryAccountId,
                    onRequiresSupport: onActivationRequiresSupport
                )
                let succeeded = plaidVM?.state == .success
                if succeeded {
                    try? await KeychainManager.shared.save(
                        pin, for: KeychainManager.Keys.cardPinForCurrentUser, protection: .backgroundSafe
                    )
                }
                await MainActor.run {
                    isLoading = false
                    SpinnerView.hideFullScreen()
                    if succeeded { onActivated?() }
                }
            }
        }
    }

    /// `UIApplication.dismissKeyboard()` (`sendAction(resignFirstResponder...)`)
    /// resigns whatever the CURRENT responder chain points at, but this screen's
    /// PIN entry uses a near-invisible `TextField` (`PinBoxRow`, opacity 0.011) and
    /// submit() immediately transitions into a new presented screen (the wallet
    /// SDK / next cover) — in that combination the responder-chain approach can
    /// leave the keyboard visually stuck up. Forcing the key window itself to end
    /// editing reaches the field regardless, so the keyboard is reliably gone
    /// before the next screen appears.
    func dismissKeyboardForcefully() {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .endEditing(true)
    }
}

// MARK: - PinBoxRow

/// 4-digit PIN row: transparent TextField captures keystrokes;
/// PinCell renders the visual state. Eye toggle is display-only —
/// underlying field is always a TextField so .numberPad is guaranteed.
private struct PinBoxRow: View {

    @Binding var pin: String
    let isVisible: Bool
    let isFocused: Bool
    let isError: Bool
    let isLoading: Bool
    let focusField: () -> Void
    let field: CreateCashCardView.Field
    @FocusState.Binding var focusedField: CreateCashCardView.Field?
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: Spacing.md + 2) {
                ForEach(0..<4, id: \.self) { i in
                    PinCell(
                        char: char(at: i),
                        isVisible: isVisible,
                        isActive: isFocused && activeIndex == i,
                        isError: isError
                    )
                }
            }
            .allowsHitTesting(false)

            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: field)
                .tint(.clear)
                .foregroundStyle(.clear)
                .disabled(isLoading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.011)
                .onChange(of: pin) { v in
                    let filtered = String(v.filter(\.isNumber).prefix(4))
                    if filtered != v { pin = filtered }
                    if filtered.count == 4 { onComplete() }
                }
        }
        .frame(height: 58)
        .contentShape(Rectangle())
        .onTapGesture { focusField() }
    }

    private func char(at i: Int) -> String? {
        guard pin.count > i else { return nil }
        return String(pin[pin.index(pin.startIndex, offsetBy: i)])
    }

    private var activeIndex: Int { min(pin.count, 3) }
}

// MARK: - PinCell

private struct PinCell: View {
    let char: String?
    let isVisible: Bool
    let isActive: Bool
    let isError: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .stroke(borderColor, lineWidth: isActive ? Stroke.medium : Stroke.thin)
                )

            if let char {
                Text(isVisible ? char : "•")
                    .font(.system(
                        size: isVisible ? Typography.cardHero.size : 26,
                        weight: .semibold
                    ))
                    .foregroundStyle(Color.movo.textPrimary)
                    .transition(.opacity)
            } else if isActive {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.movo.accent)
                    .frame(width: Stroke.thick, height: 22)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: char)
        .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: isActive)
    }

    private var borderColor: Color {
        if isError     { return Color.movo.danger.opacity(0.7) }
        if isActive    { return Color.movo.accentBorder }
        if char != nil { return Color.movo.borderStrong }
        return Color.movo.border
    }
}
