//
//  TextInputAlertPresenter.swift
//  MovocashIOS
//
//  Created by Movo Developer on 16/03/26.
//


import SwiftUI

// MARK: - Presentation Style

enum TextInputPresentationStyle {
    case center
    case sheet
}

// MARK: - TextInputAlertPresenter

struct TextInputAlertPresenter<Content: View>: View {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var placeholder: String
    var config: TextInputAlertConfig = .init()
    var style: TextInputPresentationStyle = .center  // ← default center
    var onCreate: (String) -> Void
    var onCancel: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @State private var inputText: String = ""

    var body: some View {
        switch style {
        case .center:
            centerPresenter
        case .sheet:
            sheetPresenter
        }
    }

    // MARK: - Center

    private var centerPresenter: some View {
        ZStack {
            content()

            if isPresented {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .zIndex(98)

                TextInputAlertView(
                    title: title,
                    message: message,
                    placeholder: placeholder,
                    config: config,
                    text: $inputText,
                    onCreate: { commit() },
                    onCancel: { cancel() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(99)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
    }

    // MARK: - Bottom Sheet

    private var sheetPresenter: some View {
        content()
            .sheet(isPresented: $isPresented) {
                sheetContent
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(config.cornerRadius)
                    .onDisappear { inputText = "" }
            }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {

            // Header
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

            // TextField
            VStack(spacing: 16) {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 20)
            .background(Color.movo.surface)

            // Buttons
            Divider()
            HStack(spacing: 0) {
                Button { cancel() } label: {
                    Text(config.secondaryLabel)
                }
                .buttonStyle(MovoTextButtonStyle())

                Divider().frame(height: 44)

                Button {
                    guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    commit()
                } label: {
                    Text(config.primaryLabel)
                }
                .buttonStyle(MovoCompactButtonStyle())
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .background(Color.movo.surface)
        }
    }

    // MARK: - Actions

    private func commit() {
        let name = inputText.trimmingCharacters(in: .whitespaces)
        isPresented = false
        inputText = ""
        UIApplication.shared.dismissKeyboard()
        onCreate(name)
    }

    private func cancel() {
        isPresented = false
        inputText = ""
        onCancel?()
    }
}

// MARK: - View Extension

extension View {
    func textInputAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        placeholder: String,
        config: TextInputAlertConfig = .init(),
        style: TextInputPresentationStyle = .center,
        onCreate: ( (String) -> Void)? = nil,  // ← optional but still passes String
        onCancel: (() -> Void)? = nil
    ) -> some View {
        TextInputAlertPresenter(
            isPresented: isPresented,
            title: title,
            message: message,
            placeholder: placeholder,
            config: config,
            style: style,
            onCreate: { name in onCreate?(name) },       // ← unwrap safely
            onCancel: onCancel
        ) { self }
    }
}
