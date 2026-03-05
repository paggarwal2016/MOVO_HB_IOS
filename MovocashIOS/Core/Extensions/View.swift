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
