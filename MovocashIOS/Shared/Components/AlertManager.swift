//
//  AlertManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import SwiftUI
import Combine

enum AppAlertType: Identifiable {
    case error(message: String)
    case confirmation(title: String, message: String)
    case custom(title: String, message: String, primary: String, secondary: String?)
    case textInput(title: String, message: String, placeholder: String)

    var id: String {
        switch self {
        case .error(let message): return "error_\(message)"
        case .confirmation(let title, let message): return "confirmation_\(title)_\(message)"
        case .custom(let title, let message, _, _): return "custom_\(title)_\(message)"
        case .textInput(let title, _, _): return "textInput_\(title)"
        }
    }
}

// MARK: - AlertManager Protocol

@MainActor
protocol AlertManagerProtocol {
    func showError(_ message: String, onDismiss: (() -> Void)?)
    func showConfirmation(title: String, message: String, onConfirm: (() -> Void)?, onCancel: (() -> Void)?)
}

extension AlertManagerProtocol {
    func showError(_ message: String) {
        showError(message, onDismiss: nil)
    }
}

// MARK: - AlertManager

@MainActor
final class AlertManager: ObservableObject, AlertManagerProtocol {
    static let shared = AlertManager()
    @Published var currentAlert: AppAlertType?
    @Published var inputText: String = ""

    private var primaryAction: (() -> Void)?
    private var secondaryAction: (() -> Void)?

    private init() {}

    // MARK: - Show Alerts
    func showError(_ message: String, onDismiss: (() -> Void)? = nil) {
        primaryAction = onDismiss
        currentAlert = .error(message: message)
    }

    func showConfirmation(title: String, message: String, onConfirm: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        primaryAction = onConfirm
        secondaryAction = onCancel
        currentAlert = .confirmation(title: title, message: message)
    }

    func showCustom(title: String, message: String, primary: String, secondary: String? = nil, onPrimary: (() -> Void)? = nil, onSecondary: (() -> Void)? = nil) {
        primaryAction = onPrimary
        secondaryAction = onSecondary
        currentAlert = .custom(title: title, message: message, primary: primary, secondary: secondary)
    }
    
    // MARK: NEW — Text Input Alert
    
    func showTextInput(
        title: String,
        message: String,
        placeholder: String,
        onCreate: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        inputText = ""
        primaryAction = { [weak self] in
            guard let self else { return }
            onCreate?(self.inputText)
        }
        secondaryAction = onCancel
        currentAlert = .textInput(title: title, message: message, placeholder: placeholder)
    }


    // MARK: - Trigger Actions
    func triggerPrimary() { primaryAction?(); dismiss() }
    func triggerSecondary() { secondaryAction?(); dismiss() }
    func dismiss() { primaryAction = nil; secondaryAction = nil; currentAlert = nil }
}

// MARK: - GlobalAlertModifier (updated)

struct GlobalAlertModifier: ViewModifier {
    @StateObject private var alertManager = AlertManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                // Existing native alerts (exclude textInput)
                .alert(item: Binding(
                    get: {
                        if case .textInput = alertManager.currentAlert { return nil }
                        return alertManager.currentAlert
                    },
                    set: { newValue in DispatchQueue.main.async { alertManager.currentAlert = newValue } }
                )) { alert in
                    switch alert {
                    case .error(let message):
                        return Alert(
                            title: Text("Error"), message: Text(message),
                            dismissButton: .default(Text("OK")) { alertManager.triggerPrimary() }
                        )
                    case .confirmation(let title, let message):
                        return Alert(
                            title: Text(title), message: Text(message),
                            primaryButton: .destructive(Text("Yes")) { alertManager.triggerPrimary() },
                            secondaryButton: .cancel { alertManager.triggerSecondary() }
                        )
                    case .custom(let title, let message, let primary, let secondary):
                        if let secondary {
                            return Alert(
                                title: Text(title), message: Text(message),
                                primaryButton: .default(Text(primary)) { alertManager.triggerPrimary() },
                                secondaryButton: .cancel(Text(secondary)) { alertManager.triggerSecondary() }
                            )
                        } else {
                            return Alert(
                                title: Text(title), message: Text(message),
                                dismissButton: .default(Text(primary)) { alertManager.triggerPrimary() }
                            )
                        }
                    case .textInput:
                        return Alert(title: Text("")) // never reached
                    }
                }

            // NEW — TextInput overlay alert
            if case .textInput(let title, let message, let placeholder) = alertManager.currentAlert {
                TextInputAlertView(
                    title: title,
                    message: message,
                    placeholder: placeholder,
                    text: $alertManager.inputText,
                    onCreate: {
                        alertManager.triggerPrimary()
                    },
                    onCancel: {
                        alertManager.triggerSecondary()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: alertManager.currentAlert?.id)
    }
}


extension View { func globalAlert() -> some View { self.modifier(GlobalAlertModifier()) } }
