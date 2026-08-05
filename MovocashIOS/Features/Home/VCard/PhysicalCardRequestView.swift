//
//  PhysicalCardRequestView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/08/26.
//

import SwiftUI

struct PhysicalCardRequestView: View {

    let vm: VCardViewModel
    let accountId: Int
    let plasticId: Int
    let profile: UserProfileResponse?
    let onClose: () -> Void
    /// Called after the user dismisses the success alert — the caller navigates
    /// back to the Dashboard from here.
    var onIssued: (() -> Void)? = nil

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showPin = false
    @State private var showConfirmPin = false
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var issuedDetail: PhysicalCardDetail?
    @FocusState private var focusedField: Field?

    fileprivate enum Field { case pin, confirmPin }

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
        pin.count == 4 && pin.allSatisfy(\.isNumber) && !isPinWeak &&
        confirmPin.count == 4 && pinsMatch
    }

    private var successMessage: String {
        guard let issuedDetail else {
            return "Your physical card has been issued and will arrive by mail."
        }
        let lastFour = issuedDetail.lastFour ?? "••••"
        return "Your physical card ending in \(lastFour) has been issued and will arrive by mail.\nExpires \(issuedDetail.expiryMMYY)."
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    heroSection

                    Divider().background(Color.movo.border)

                    pinArea
                    
                    Divider().background(Color.movo.border)
                    
                    disclaimerRow("Your card will be securely issued and delivered to the address above.")
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
        }
        .background(Color.movo.surface.ignoresSafeArea())
        .onDisappear { SpinnerView.hideFullScreen() }
        .alert("Card Issued!", isPresented: $showSuccessAlert) {
            Button("OK") { onIssued?() }
        } message: {
            Text(successMessage)
        }
        .globalAlert()
    }
}

// MARK: - Header

private extension PhysicalCardRequestView {

    var header: some View {
        ZStack {
            Text("Physical Card")
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .frame(maxWidth: .infinity)
            HStack {
                CustomBackButton { onClose() }
                Spacer()
            }
        }
    }
}

// MARK: - Hero

private extension PhysicalCardRequestView {

    var heroSection: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("We'll issue your")
                        .textStyle(Typography.heroTitle)
                        .foregroundStyle(Color.movo.textPrimary)
                    Text("Physical Card")
                        .textStyle(Typography.heroTitle)
                        .foregroundStyle(Color.movo.accent)
                }

                addressBlock
            }
            Spacer(minLength: Spacing.md)
            cardArtwork
        }
    }

    var cardArtwork: some View {
        Image("CardFrontHerring")
            .resizable()
            .scaledToFit()
            .frame(width: 130)
            .cardArtworkShadow()
    }
}

// MARK: - Address

private extension PhysicalCardRequestView {

    var addressBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.movo.accent)
                Text("DELIVERY ADDRESS")
                    .textStyle(Typography.eyebrow)
                    .foregroundStyle(Color.movo.accent)
            }
            .padding(.bottom, Spacing.xxs)

            if let addressName {
                Text(addressName)
                    .textStyle(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.movo.textPrimary)
            }
            if let addressStreet {
                Text(addressStreet)
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textSecondary)
            }
            if let addressCityLine {
                Text(addressCityLine)
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textSecondary)
            }
            if let addressPhone {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.movo.textTertiary)
                    Text(addressPhone)
                        .textStyle(Typography.mono)
                        .foregroundStyle(Color.movo.textSecondary)
                }
                .padding(.top, Spacing.xxs)
            }

            if addressName == nil, addressStreet == nil, addressCityLine == nil {
                Text("—")
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textSecondary)
            }
        }
    }

    var addressName: String? {
        guard let profile, profile.fullName != "—" else { return nil }
        return profile.fullName
    }

    var addressStreet: String? {
        let street = [profile?.addressLine1, profile?.addressLine2]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return street.isEmpty ? nil : street
    }

    var addressCityLine: String? {
        let stateZip = [profile?.state, profile?.zip]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let cityLine = [profile?.city?.trimmingCharacters(in: .whitespaces), stateZip]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return cityLine.isEmpty ? nil : cityLine
    }

    var addressPhone: String? {
        guard let profile, profile.displayPhone != "—" else { return nil }
        return profile.displayPhone
    }
}

// MARK: - PIN Entry

private extension PhysicalCardRequestView {

    var pinArea: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.movo.accent)
                    Text("CARD PIN")
                        .textStyle(Typography.eyebrow)
                        .foregroundStyle(Color.movo.accent)
                }
                .padding(.bottom, Spacing.xxs)

                Text("Your PIN will be used for ATM and POS transactions.")
                    .textStyle(Typography.subtitle)
                    .foregroundStyle(Color.movo.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.lg) {
                pinSection
                confirmPinSection
            }
        }
    }

    var pinSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                fieldLabel("PIN")
                Spacer()
                eyeToggle(isOn: $showPin)
            }
            PhysicalPinBoxRow(
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
            PhysicalPinBoxRow(
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

// MARK: - Footer / Submit

private extension PhysicalCardRequestView {

    var footer: some View {
        VStack(spacing: Spacing.lg) {
            Button(action: submit) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "creditcard.fill")
                    Text("Issue the Card")
                }
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(!isValid || isLoading)
            .opacity(isValid && !isLoading ? 1.0 : 0.4)
        }
    }

    func disclaimerRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.movo.textTertiary)
            Text(text)
                .textStyle(Typography.caption)
                .foregroundStyle(Color.movo.textTertiary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.xs)
    }

    func submit() {
        guard isValid else { return }
        focusedField = nil
        isLoading = true
        dismissKeyboardForcefully()
        SpinnerView.showFullScreen()
        let request = PhysicalCardRequest(
            accountId: accountId,
            pin: pin,
            plasticId: plasticId,
            userAction: "ISSUE-PHYSICAL-CARD"
        )
        Task {
            let response = try? await vm.requestPhysicalCard(request: request)
            await MainActor.run {
                isLoading = false
                SpinnerView.hideFullScreen()
                if let response, response.success {
                    issuedDetail = response.data
                    showSuccessAlert = true
                }
            }
        }
    }

    func dismissKeyboardForcefully() {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .endEditing(true)
    }
}

// MARK: - PhysicalPinBoxRow / PhysicalPinCell

/// 4-digit PIN row for this screen — mirrors CreateCashCardView's PinBoxRow/PinCell,
/// reimplemented locally since those types are private to that file.
private struct PhysicalPinBoxRow: View {

    @Binding var pin: String
    let isVisible: Bool
    let isFocused: Bool
    let isError: Bool
    let isLoading: Bool
    let focusField: () -> Void
    let field: PhysicalCardRequestView.Field
    @FocusState.Binding var focusedField: PhysicalCardRequestView.Field?
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: Spacing.md + 2) {
                ForEach(0..<4, id: \.self) { i in
                    PhysicalPinCell(
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

private struct PhysicalPinCell: View {
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
