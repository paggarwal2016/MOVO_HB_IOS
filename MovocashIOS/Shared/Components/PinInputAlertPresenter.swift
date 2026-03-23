//
//  PinInputAlertPresenter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/03/26.
//

import Foundation
import SwiftUI

// MARK: - PinInputAlertPresenter

struct PinInputAlertPresenter<Content: View>: View {
    
    // MARK: - Properties
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var pinPlaceholder: String = "Enter PIN"
    var confirmPlaceholder: String = "Confirm PIN"
    var pinMaxLength: Int = 4               // ✅ configurable PIN length
    var config: TextInputAlertConfig = .init()
    var style: TextInputPresentationStyle = .sheet
    var onCreate: (String) -> Void
    var onCancel: (() -> Void)?
    @ViewBuilder var content: () -> Content
    
    // MARK: - State
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String? = nil
    
    // MARK: - Validation
    private var pinsMatch: Bool {
        !pin.isEmpty && pin == confirmPin
    }
    
    private var isPinValid: Bool {
        pin.count == pinMaxLength           // ✅ must match exact length
    }
    
    private var isDisabled: Bool {
        pin.count != pinMaxLength || confirmPin.count != pinMaxLength  // ✅ both must be full length
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
                    
                    // Header
                    headerView
                    
                    // Fields
                    pinFieldsView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    
                    // Buttons
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
                HStack {
                    Text("PIN")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                SecureField(pinPlaceholder, text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .onChange(of: pin) { newValue in
                        pinError = nil
                        if newValue.count > pinMaxLength {        // ✅ block extra chars
                            pin = String(newValue.prefix(pinMaxLength))
                        }
                    }
            }
            
            // Confirm PIN field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Confirm PIN")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                SecureField(confirmPlaceholder, text: $confirmPin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .onChange(of: confirmPin) { newValue in
                        pinError = nil
                        if newValue.count > pinMaxLength {        // ✅ block extra chars
                            confirmPin = String(newValue.prefix(pinMaxLength))
                        }
                    }
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
            
            // Cancel
            Button { cancel() } label: {
                Text(config.secondaryLabel)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(config.secondaryColor)
            }
            
            Divider().frame(height: 44)
            
            // Confirm
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
        pinMaxLength: Int = 4,              // ✅ default 4 digits
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
