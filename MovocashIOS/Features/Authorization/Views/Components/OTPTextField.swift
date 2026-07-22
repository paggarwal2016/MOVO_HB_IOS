//
//  OTPTextField.swift
//  MovocashIOS
//

import SwiftUI
import UIKit

/// UIViewRepresentable wrapper around UITextField, purpose-built for SMS OTP autofill.

struct OTPTextField: UIViewRepresentable {

    /// Current OTP text — read in updateUIView to sync display; never written here.
    @Binding var text: String
    /// Bridges @State isFocused in OTPScreen ↔ UITextField.isFirstResponder.
    @Binding var isFocused: Bool
    let maxLength: Int
    /// Receives already-filtered text after every edit; routes to OTPViewModel.updateOTP.
    let onTextChange: (String) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextField {
        let field = NoMenuTextField()
        field.textContentType = .oneTimeCode
        field.keyboardType = .numberPad
        field.autocorrectionType = .no
        field.textColor = .clear
        field.backgroundColor = .clear
        field.tintColor = .clear
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Equality guard — the only write that matters.
        // SwiftUI calls updateUIView on every render pass. Without this guard it would
        // unconditionally set uiView.text, landing mid-autofill and cancelling UIKit's
        // in-progress fill transaction. The equality check means:
        //   • Same value  → skip, autofill transaction is untouched.
        //   • Diff value  → write (e.g. resetForResend clears "" while keyboard is up).
        if uiView.text != text {
            uiView.text = text
        }

        // Bridge SwiftUI focus state → UIKit first-responder.
        // Guards on actual state prevent redundant become/resign calls and loops.
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFocused: $isFocused, maxLength: maxLength, onTextChange: onTextChange)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate {

        private var isFocused: Binding<Bool>
        let maxLength: Int
        let onTextChange: (String) -> Void

        init(isFocused: Binding<Bool>, maxLength: Int, onTextChange: @escaping (String) -> Void) {
            self.isFocused = isFocused
            self.maxLength = maxLength
            self.onTextChange = onTextChange
        }

        /// Always returns true — rejecting the replacement string during an autofill
        /// insertion cancels the fill entirely. Digit filtering and maxLength limiting
        /// are handled in editingChanged instead (one filter path, not two).
        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            return true
        }

        @objc func editingChanged(_ sender: UITextField) {
            let raw = sender.text ?? ""
            let filtered = String(raw.filter { $0.isNumber }.prefix(maxLength))
            // Only correct the UITextField when filtering actually changed something
            // (e.g. a non-digit character arrived alongside the code).
            if sender.text != filtered {
                sender.text = filtered
            }
            // Route through OTPViewModel.updateOTP — filtering is done here, not there.
            onTextChange(filtered)
        }

        // MARK: Focus reporting

        func textFieldDidBeginEditing(_ textField: UITextField) {
            let binding = isFocused
            DispatchQueue.main.async {
                if !binding.wrappedValue { binding.wrappedValue = true }
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            let binding = isFocused
            DispatchQueue.main.async {
                if binding.wrappedValue { binding.wrappedValue = false }
            }
        }
    }
}

/// UITextField that suppresses the Cut/Copy/Paste/Select edit menu.
///
private final class NoMenuTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
}

