//
//  AlertManager.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import SwiftUI
import Combine

enum AppAlertType {
    case error(message: String)
    case confirmation(title: String, message: String)
    case custom(title: String, message: AttributedString, primary: String, secondary: String?, primaryIcon: String?, icon: CustomAlertIcon)
    case textInput(title: String, message: String, placeholder: String)
}

struct IdentifiedAlert: Identifiable {
    let id = UUID()
    let type: AppAlertType
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
    @Published var currentAlert: IdentifiedAlert?
    @Published var inputText: String = ""

    private var primaryAction: (() -> Void)?
    private var secondaryAction: (() -> Void)?

    private init() {}

    // MARK: - Show Alerts
    func showError(_ message: String, onDismiss: (() -> Void)? = nil) {
        primaryAction = onDismiss
        currentAlert = IdentifiedAlert(type: .error(message: message))
    }

    func showConfirmation(title: String, message: String, onConfirm: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        primaryAction = onConfirm
        secondaryAction = onCancel
        currentAlert = IdentifiedAlert(type: .confirmation(title: title, message: message))
    }

    func showCustom(title: String, message: AttributedString, primary: String, secondary: String? = nil, primaryIcon: String? = nil, icon: CustomAlertIcon = .success, onPrimary: (() -> Void)? = nil, onSecondary: (() -> Void)? = nil) {
        primaryAction = onPrimary
        secondaryAction = onSecondary
        currentAlert = IdentifiedAlert(type: .custom(title: title, message: message, primary: primary, secondary: secondary, primaryIcon: primaryIcon, icon: icon))
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
        currentAlert = IdentifiedAlert(type: .textInput(title: title, message: message, placeholder: placeholder))
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
                // Native alerts for .error / .confirmation only. .custom and
                // .textInput are rendered as design-system overlays below, so they
                // are filtered out of the native-alert binding.
                .alert(item: Binding(
                    get: {
                        if case .textInput = alertManager.currentAlert?.type { return nil }
                        if case .custom = alertManager.currentAlert?.type { return nil }
                        return alertManager.currentAlert
                    },
                    set: { newValue in Task { @MainActor in alertManager.currentAlert = newValue } }
                )) { alert in
                    switch alert.type {
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
                    case .custom, .textInput:
                        return Alert(title: Text("")) // never reached — handled by overlays
                    }
                }

            // Design-system styled custom alert overlay.
            if case .custom(let title, let message, let primary, let secondary, let primaryIcon, let icon) = alertManager.currentAlert?.type {
                CustomAlertView(
                    title: title,
                    message: message,
                    primary: primary,
                    secondary: secondary,
                    primaryIcon: primaryIcon,
                    icon: icon,
                    onPrimary: { alertManager.triggerPrimary() },
                    onSecondary: { alertManager.triggerSecondary() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(1)
            }

            // NEW — TextInput overlay alert
            if case .textInput(let title, let message, let placeholder) = alertManager.currentAlert?.type {
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
