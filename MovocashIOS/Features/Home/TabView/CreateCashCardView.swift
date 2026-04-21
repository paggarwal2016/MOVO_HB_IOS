//
//  CreateCashCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 21/04/26.
//

import SwiftUI

struct CreateCashCardView: View {

    // MARK: - Callbacks
    let onCancel: () -> Void
    let onCreate: (_ nickname: String, _ pin: String) async -> Void

    // MARK: - State
    @State private var nickname = ""
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case nickname, pin, confirmPin }

    private var pinsMatch: Bool { pin == confirmPin }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        pin.count == 4 &&
        pin.allSatisfy(\.isNumber) &&
        confirmPin.count == 4 &&
        pinsMatch
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

            fieldsSection
                .padding(.horizontal, 20)

            Spacer()

            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .overlay {
            if isLoading {
                SpinnerView()
            }
        }
    }
}

// MARK: - Subviews

private extension CreateCashCardView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Create Card")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text("Give your card a nickname and set a secure PIN.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }

    var fieldsSection: some View {
        VStack(spacing: 14) {
            labeledField(label: "Nickname") {
                TextField("e.g. Enter the card name", text: $nickname)
                    .focused($focusedField, equals: .nickname)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .pin }
                    .disabled(isLoading)
            }

            labeledField(label: "PIN") {
                SecureField("4-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .pin)
                    .disabled(isLoading)
                    .onChange(of: pin) { newValue in
                        pin = String(newValue.filter(\.isNumber).prefix(4))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm PIN")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                SecureField("Re-enter 4-digit PIN", text: $confirmPin)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .confirmPin)
                    .disabled(isLoading)
                    .onChange(of: confirmPin) { newValue in
                        confirmPin = String(newValue.filter(\.isNumber).prefix(4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                confirmPin.count == 4 && !pinsMatch
                                    ? Color.red.opacity(0.7)
                                    : Color(.systemGray4),
                                lineWidth: 1
                            )
                    )

                if confirmPin.count == 4 && !pinsMatch {
                    Text("PINs do not match.")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
    }

    func labeledField<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            field()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        }
    }

    var actionButtons: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Create", isLoading: isLoading, isEnabled: isValid && !isLoading) {
                submit()
            }
            Button("Cancel") {
                onCancel()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Actions

private extension CreateCashCardView {

    func submit() {
        guard isValid else { return }
        focusedField = nil
        isLoading = true
        Task {
            await onCreate(nickname.trimmingCharacters(in: .whitespaces), pin)
            isLoading = false
        }
    }
}
