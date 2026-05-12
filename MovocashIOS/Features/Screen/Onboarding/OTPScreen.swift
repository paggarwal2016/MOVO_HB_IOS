//
//  OTPScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct OTPScreen: View {
    @StateObject private var otpVM: OTPViewModel
    @FocusState private var isFocused: Bool

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
            
            VStack(alignment: .leading, spacing: 24) {
                topBar
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
    }
}

// MARK: - Subviews
private extension OTPScreen {

    private var topBar: some View {
        HStack {
            Button(action: {
                UIApplication.shared.dismissKeyboard()
                onBack()
            }) {
                BackChevronIcon(tint: Color.movo.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }


    var titleView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Color.movo.textPrimary)
                .lineSpacing(2)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.movo.textTertiary)
                .lineSpacing(2)
        }
    }

    var otpSectionView: some View {
        VStack(spacing: 12) {
            otpBoxesView
            hiddenTextField
            resendView
        }
    }

    var otpBoxesView: some View {
        HStack(spacing: 12) {
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
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    var hiddenTextField: some View {
        TextField("", text: otpBinding)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .frame(width: 1, height: 1)
            .opacity(0.01)
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
            .font(.subheadline.bold())
            .foregroundColor(Color.movo.accent)
            .frame(maxWidth: .infinity, alignment: .center)

        case .idle:
            EmptyView()
        }
    }

    var continueButton: some View {
        PrimaryButton(title: "Continue", isEnabled: otpVM.isValidOTP && !otpVM.isSubmitting) {
            UIApplication.shared.dismissKeyboard()
            Task {
                await otpVM.submitOTP { await onVerify($0) }
            }
        }
        .disabled(!otpVM.isValidOTP || isLoading || otpVM.isSubmitting)
    }
}

// MARK: - Helpers
private extension OTPScreen {

    var otpBinding: Binding<String> {
        Binding(
            get: { otpVM.otpText },
            set: { otpVM.updateOTP($0) }
        )
    }

    func digit(at index: Int) -> String {
        guard index < otpVM.otpText.count else { return "" }
        let i = otpVM.otpText.index(otpVM.otpText.startIndex, offsetBy: index)
        return String(otpVM.otpText[i])
    }

    func setupOnAppear() {
        otpVM.startTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isFocused = true
        }
    }

    func handleOTPChange(_ newValue: String) {
        guard newValue.count == otpVM.maxLength, !otpVM.isSubmitting else { return }
        isFocused = false
        UIApplication.shared.dismissKeyboard()
        Task {
            await otpVM.submitOTP { await onVerify($0) }
        }
    }
}
