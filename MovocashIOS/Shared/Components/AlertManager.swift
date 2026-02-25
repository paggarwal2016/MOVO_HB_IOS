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

    var id: String {
        switch self {
        case .error(let message): return "error_\(message)"
        case .confirmation(let title, let message): return "confirmation_\(title)_\(message)"
        case .custom(let title, let message, _, _): return "custom_\(title)_\(message)"
        }
    }
}

@MainActor
final class AlertManager: ObservableObject {
    static let shared = AlertManager()
    @Published var currentAlert: AppAlertType?

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

    // MARK: - Trigger Actions
    func triggerPrimary() { primaryAction?(); dismiss() }
    func triggerSecondary() { secondaryAction?(); dismiss() }
    func dismiss() { primaryAction = nil; secondaryAction = nil; currentAlert = nil }
}

// MARK: - Modifier
struct GlobalAlertModifier: ViewModifier {
    @StateObject private var alertManager = AlertManager.shared

    func body(content: Content) -> some View {
        content.alert(item: $alertManager.currentAlert) { alert in
            switch alert {
            case .error(let message):
                return Alert(title: Text("Error"), message: Text(message),
                             dismissButton: .default(Text("OK")) { alertManager.triggerPrimary() })
            case .confirmation(let title, let message):
                return Alert(title: Text(title), message: Text(message),
                             primaryButton: .destructive(Text("Yes")) { alertManager.triggerPrimary() },
                             secondaryButton: .cancel { alertManager.triggerSecondary() })
            case .custom(let title, let message, let primary, let secondary):
                if let secondary = secondary {
                    return Alert(title: Text(title), message: Text(message),
                                 primaryButton: .default(Text(primary)) { alertManager.triggerPrimary() },
                                 secondaryButton: .cancel(Text(secondary)) { alertManager.triggerSecondary() })
                } else {
                    return Alert(title: Text(title), message: Text(message),
                                 dismissButton: .default(Text(primary)) { alertManager.triggerPrimary() })
                }
            }
        }
    }
}

extension View { func globalAlert() -> some View { self.modifier(GlobalAlertModifier()) } }
