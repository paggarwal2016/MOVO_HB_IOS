//
//  OTPScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import OSLog
import SwiftUI

// TODO: remove before merge
private let logger = Logger(subsystem: "com.movo.otp", category: "autofill")

struct OTPScreen: View {
    @StateObject private var otpVM: OTPViewModel
    // @State instead of @FocusState: focus is managed via UIKit (becomeFirstResponder /
    // resignFirstResponder) inside OTPTextField.updateUIView, so SwiftUI's focus engine
    // is not needed here. @State gives a plain Binding<Bool> that OTPTextField accepts.
    @State private var isFocused: Bool = false

    let title: String
    let subtitle: String
    let isLoading: Bool
    let onVerify: @MainActor (String) async -> Void
    let onResend: @MainActor () async throws -> Void
    let onBack: @MainActor () -> Void

    init(
        title: String,
        subtitle: String,
        maxLength: Int = 6,
        isLoading: Bool = false,
        onVerify: @escaping @MainActor (String) async -> Void,
        onResend: @escaping @MainActor () async throws -> Void,
        onBack: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isLoading = isLoading
        self.onVerify = onVerify
        self.onResend = onResend
        self.onBack = onBack
        self._otpVM = StateObject(wrappedValue: OTPViewModel(maxLength: maxLength))
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(alignment: .leading, spacing: Spacing.xxl) {
                topBar
                    .padding(.bottom, DesignTokens.Spacing.xl)
                titleView
                otpSectionView
                Spacer()
                continueButton
            }
            .padding()

            if isLoading {
                SpinnerView()
            }
        }
        .onAppear(perform: setupOnAppear)
        .onChangeCompat(of: otpVM.otpText, perform: handleOTPChange)
        .onChangeCompat(of: isFocused) { newValue in // TODO: remove before merge
            let ts = Date().formatted(.dateTime.hour().minute().second())
            logger.debug("[autofill] isFocused → \(newValue) at \(ts)")
        }
    }
}

// MARK: - Subviews
private extension OTPScreen {

    private var topBar: some View {
        HStack {
            CustomBackButton() {
                UIApplication.shared.dismissKeyboard()
                onBack()
            }
            Spacer()
        }
    }

    var titleView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)

            Text(subtitle)
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }

    var otpSectionView: some View {
        VStack(spacing: Spacing.md) {
            // OTPTextField (UIViewRepresentable) overlays the visual boxes and owns all
            // keyboard/autofill interaction. It has a clear background and clear text
            // colour, so only the blinking cursor is visible — intentionally, so iOS
            // autofill can detect the active field.
            otpBoxesView
                .overlay(
                    OTPTextField(
                        text: $otpVM.otpText,
                        isFocused: $isFocused,
                        maxLength: otpVM.maxLength,
                        onTextChange: { otpVM.updateOTP($0) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            resendView
        }
    }

    var otpBoxesView: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0..<otpVM.maxLength, id: \.self) { index in
                OTPDigitBox(
                    digit: digit(at: index),
                    isActive: otpVM.otpText.count == index && isFocused,
                    isFilled: index < otpVM.otpText.count
                )
                .frame(maxWidth: .infinity)
                .frame(height: 55)
            }
        }
    }

    @ViewBuilder
    var resendView: some View {
        switch otpVM.state {
        case .counting:
            Text("Resend OTP in 0:\(String(format: "%02d", otpVM.remainingSeconds))")
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

        case .expired:
            Button("Resend OTP") {
                Task {
                    otpVM.resetForResend()
                    try? await onResend()
                }
            }
            .textStyle(Typography.bodyCompact)
            .foregroundColor(Color.movo.accent)
            .frame(maxWidth: .infinity, alignment: .center)

        case .idle:
            EmptyView()
        }
    }

    var continueButton: some View {
        let isEnabled = otpVM.isValidOTP && !isLoading && !otpVM.isSubmitting
        return Button {
            UIApplication.shared.dismissKeyboard()
            Task {
                await otpVM.submitOTP { await onVerify($0) }
            }
        } label: {
            Text("Continue")
        }
        .buttonStyle(MovoPrimaryButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
    }
}

// MARK: - Helpers
private extension OTPScreen {

    func digit(at index: Int) -> String {
        guard index < otpVM.otpText.count else { return "" }
        let i = otpVM.otpText.index(otpVM.otpText.startIndex, offsetBy: index)
        return String(otpVM.otpText[i])
    }

    func setupOnAppear() {
        otpVM.startTimer()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            isFocused = true
            // TODO: remove before merge
            logger.debug("[autofill] setupOnAppear: isFocused set to true after 0.3 s")
            try? await Task.sleep(for: .seconds(0.5))
            // TODO: remove before merge
            logger.debug("[autofill] setupOnAppear: isFocused after 0.5 s stabilisation = \(isFocused)")
        }
    }

    func handleOTPChange(_ newValue: String) {
        // TODO: remove before merge
        logger.debug("[autofill] handleOTPChange: count=\(newValue.count) isSubmitting=\(otpVM.isSubmitting)")
        guard newValue.count == otpVM.maxLength, !otpVM.isSubmitting else {
            // TODO: remove before merge
            logger.debug("[autofill] handleOTPChange: guard failed — not submitting")
            return
        }
        // TODO: remove before merge
        logger.debug("[autofill] handleOTPChange: submitting")
        isFocused = false
        UIApplication.shared.dismissKeyboard()
        Task {
            await otpVM.submitOTP { await onVerify($0) }
        }
    }
}
