//
//  CreateCashCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 21/04/26.
//

import SwiftUI

struct CreateCashCardView: View {

    // MARK: - Dependencies & Callbacks

    /// View model that performs the create-card network call.
    let vm: VCardViewModel
    /// Dismisses this sheet (used by the close button).
    let onClose: () -> Void
    /// Invoked after the card is created successfully. The presenter is expected
    /// to dismiss this sheet and then present the success screen, passing along
    /// the created card.
    let onCreated: (VCardListResponse) -> Void

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
                title: "Create your cash card",
                subtitle: "Let's MOVO your way",
                systemImage: "creditcard.fill",
                iconTint: Color.movo.accent,
                iconBackground: Color.movo.accentTint,
                horizontalPadding: Spacing.xl,
                closeAction: onClose
            )
            VStack(spacing: Spacing.xl) {
                nicknameField
                pinSection
                confirmPinSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            Spacer()
            actionButtons
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
        }
        .padding(.top, Spacing.xxl)
        .background(Color.movo.surface.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .nickname
            }
        }
        .onDisappear {
            SpinnerView.hideFullScreen()
        }
    }
}

// MARK: - Fields

private extension CreateCashCardView {

    var nicknameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            fieldLabel("CARD NAME")
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
            .disabled(isLoading)
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
            HStack(spacing: Spacing.sm) {
                Text("LET'S MOVO")
                    .tracking(1.5)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!isValid || isLoading)
        .opacity(isValid && !isLoading ? 1.0 : 0.4)
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: isValid)
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
        SpinnerView.showFullScreen()
        let request = CreateVCardRequest(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            pin: pin,
            userAction: "VCARD-CREATION"
        )
        Task {
            let card = try? await vm.createVCard(request: request)
            // Error (card == nil) is surfaced via BaseViewModel toast.
            await MainActor.run {
                isLoading = false
                SpinnerView.hideFullScreen()
                if let card { onCreated(card) }
            }
        }
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
            HStack(spacing: Spacing.sm + 2) {
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
