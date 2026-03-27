//
//  PinInputAlertPresenter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/03/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - SecureToggleField
// UIViewRepresentable wrapping a single UITextField.
// Toggling isSecure flips isSecureTextEntry without recreating the view,
// so the keyboard stays visible and focus is never lost.

struct SecureToggleField: UIViewRepresentable {

    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let maxLength: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, maxLength: maxLength)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.placeholder = placeholder
        field.isSecureTextEntry = isSecure
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Toggle secure entry without losing focus.
        // iOS clears text when toggling isSecureTextEntry, so we restore it.
        if uiView.isSecureTextEntry != isSecure {
            let saved = uiView.text
            uiView.isSecureTextEntry = isSecure
            uiView.text = saved
        }
        // Sync external state changes only when the field is not being edited.
        if !uiView.isFirstResponder, uiView.text != text {
            uiView.text = text
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let maxLength: Int

        init(text: Binding<String>, maxLength: Int) {
            _text = text
            self.maxLength = maxLength
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: r, with: string)
            let digits = updated.filter { $0.isNumber }
            guard digits.count <= maxLength else { return false }
            textField.text = digits
            text = digits
            return false
        }
    }
}

// MARK: - PinInputAlertPresenter

struct PinInputAlertPresenter<Content: View>: View {

    // MARK: - Properties
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var pinPlaceholder: String = "Enter PIN"
    var confirmPlaceholder: String = "Confirm PIN"
    var pinMaxLength: Int = 4
    var config: TextInputAlertConfig = .init()
    var style: TextInputPresentationStyle = .sheet
    var onCreate: (String) -> Void
    var onCancel: (() -> Void)?
    @ViewBuilder var content: () -> Content

    // MARK: - State
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String? = nil
    @State private var isPinVisible: Bool = false
    @State private var isConfirmPinVisible: Bool = false

    // MARK: - Validation
    private var pinsMatch: Bool {
        !pin.isEmpty && pin == confirmPin
    }

    private var isPinValid: Bool {
        pin.count == pinMaxLength
    }

    private var isDisabled: Bool {
        pin.count != pinMaxLength || confirmPin.count != pinMaxLength
    }

    // MARK: - Body
    var body: some View {
        switch style {
        case .center:
            centerPresenter
        case .sheet:
            sheetPresenter
        }
    }

    // MARK: - Center Presenter
    private var centerPresenter: some View {
        ZStack {
            content()

            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .zIndex(98)

                VStack(spacing: 0) {
                    headerView
                    pinFieldsView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    Divider()
                    buttonsView
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(99)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
    }

    // MARK: - Sheet Presenter
    private var sheetPresenter: some View {
        content()
            .sheet(isPresented: $isPresented) {
                VStack(spacing: 0) {
                    headerView
                    pinFieldsView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    Divider()
                    buttonsView
                }
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(config.cornerRadius)
                .onDisappear { resetFields() }
            }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 6) {
            if let icon = config.headerIcon {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(config.titleColor)
                    .padding(.bottom, 2)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(config.titleColor)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(config.messageColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(config.headerBackground)
    }

    // MARK: - PIN Fields
    private var pinFieldsView: some View {
        VStack(spacing: 12) {

            // PIN field
            VStack(alignment: .leading, spacing: 4) {
                Text("PIN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    SecureToggleField(
                        placeholder: pinPlaceholder,
                        text: $pin,
                        isSecure: !isPinVisible,
                        maxLength: pinMaxLength
                    )
                    .frame(height: 22)
                    .onChange(of: pin) { _ in
                        if confirmPin.count == pinMaxLength {
                            pinError = pin == confirmPin ? nil : "PINs do not match."
                        } else {
                            pinError = nil
                        }
                    }

                    Button { isPinVisible.toggle() } label: {
                        Image(systemName: isPinVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separator), lineWidth: 0.5))
            }

            // Confirm PIN field
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm PIN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    SecureToggleField(
                        placeholder: confirmPlaceholder,
                        text: $confirmPin,
                        isSecure: !isConfirmPinVisible,
                        maxLength: pinMaxLength
                    )
                    .onChange(of: confirmPin) { newValue in
                        if newValue.count == pinMaxLength {
                            pinError = newValue == pin ? nil : "PINs do not match."
                        } else {
                            pinError = nil
                        }
                    }

                    Button { isConfirmPinVisible.toggle() } label: {
                        Image(systemName: isConfirmPinVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separator), lineWidth: 0.5))
            }

            // Error message
            if let error = pinError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Buttons
    private var buttonsView: some View {
        HStack(spacing: 0) {

            Button { cancel() } label: {
                Text(config.secondaryLabel)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(config.secondaryColor)
            }

            Divider().frame(height: 44)

            Button { handleConfirm() } label: {
                Text(config.primaryLabel)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(
                        isDisabled
                        ? config.primaryColor.opacity(0.4)
                        : config.primaryColor
                    )
            }
            .disabled(isDisabled)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions
    private func handleConfirm() {
        guard isPinValid else {
            pinError = "PIN must be exactly \(pinMaxLength) digits."
            return
        }
        guard pinsMatch else {
            pinError = "PINs do not match. Please try again."
            confirmPin = ""
            return
        }
        commit()
    }

    private func commit() {
        let value = pin.trimmingCharacters(in: .whitespaces)
        isPresented = false
        resetFields()
        UIApplication.shared.dismissKeyboard()
        onCreate(value)
    }

    private func cancel() {
        isPresented = false
        resetFields()
        onCancel?()
    }

    private func resetFields() {
        pin = ""
        confirmPin = ""
        pinError = nil
        isPinVisible = false
        isConfirmPinVisible = false
    }
}

// MARK: - View Extension

extension View {
    func pinInputAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        pinPlaceholder: String = "Enter PIN",
        confirmPlaceholder: String = "Confirm PIN",
        pinMaxLength: Int = 4,
        config: TextInputAlertConfig = .init(),
        style: TextInputPresentationStyle = .sheet,
        onCreate: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        PinInputAlertPresenter(
            isPresented: isPresented,
            title: title,
            message: message,
            pinPlaceholder: pinPlaceholder,
            confirmPlaceholder: confirmPlaceholder,
            pinMaxLength: pinMaxLength,
            config: config,
            style: style,
            onCreate: { pin in onCreate?(pin) },
            onCancel: onCancel
        ) { self }
    }
}
