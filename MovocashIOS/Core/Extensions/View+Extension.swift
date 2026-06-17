//
//  View.swift
//  MovocashIOS
//
//  Created by Movo Developer on 26/02/26.
//

import SwiftUI

extension View {

    // MARK: - 1 parameter version (most common use)
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }

    // MARK: - 2 parameter version (oldValue + newValue)
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value, Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, action)
        } else {
            self.onChange(of: value) { newValue in
                action(value, newValue) // fallback approximation
            }
        }
    }
}

// MARK: - NavigationDestinationCompat Extension

extension View {
    @ViewBuilder
    func navigationDestinationCompat<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.navigationDestination(isPresented: isPresented, destination: destination)
        } else {
            ZStack {
                self
                NavigationLink(
                    destination: destination(),
                    isActive: isPresented,
                    label: { EmptyView() }
                )
                .hidden()
            }
        }
    }
}



extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}


extension View {
    func networkMonitor(state: AppState) -> some View {
        modifier(NetworkMonitorModifier(appState: state))
    }
}



extension View {
    @ViewBuilder
    func dimmedOverlay<Content: View>(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}


extension View {
    func titleStyle() -> some View {
        modifier(TitleStyle())
    }
    func subtitleStyle() -> some View {
        modifier(SubtitleStyle())
    }
}


// MARK: - Session Expiry

extension View {
    /// Runs `action` when the server broadcasts `.sessionExpired` (a 401 or
    /// session-timeout response).
    ///
    /// The handler fires synchronously, in the same notification cycle as the
    /// poster and *before* `RootView`'s deferred session reset (which wipes
    /// credentials and returns to the login flow). A screen uses it to cancel
    /// in-flight work and close its own sheets / covers so nothing sensitive
    /// lingers — and no in-flight request completes — once the session is gone.
    ///
    /// Centralizes the per-screen `onReceive(.sessionExpired)` cleanup so new
    /// sheet/cover-presenting screens can opt in with a single, consistent call.
    func onSessionExpired(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            action()
        }
    }
}
