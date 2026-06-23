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
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    fileprivate enum Field { case nickname }

    /// PINs that are too easily guessed — excluded from the randomly generated PIN.
    private static let weakPins: Set<String> = [
        "0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
        "0123", "1234", "2345", "3456", "4567", "5678", "6789", "7890",
        "9876", "8765", "7654", "6543", "5432", "4321", "3210", "0987",
        "1212", "2121", "0101", "1010", "1122", "2211", "0011", "1100",
        "2580", "1357", "1470", "2469",
    ]

    /// Generates a random 4-digit PIN, avoiding easily guessed values.
    private static func generatePin() -> String {
        var pin: String
        repeat {
            pin = String(format: "%04d", Int.random(in: 0...9999))
        } while weakPins.contains(pin)
        return pin
    }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
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
                closeAction: {
                    focusedField = nil
                    onClose()
                }
            )
            VStack(spacing: Spacing.xl) {
                nicknameField
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
            fieldLabel("NICK NAME")
            TextField(
                "",
                text: $nickname,
                prompt: Text("e.g. My Cash Card").foregroundColor(Color.movo.textDisabled)
            )
            .textStyle(Typography.body)
            .foregroundStyle(Color.movo.textPrimary)
            .tint(Color.movo.accent)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .submitLabel(.go)
            .onSubmit { submit() }
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
            pin: Self.generatePin(),
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
