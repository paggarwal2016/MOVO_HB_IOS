//
//  OTPInputView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/02/26.
//

import Foundation
import SwiftUI

struct OTPInputView: View {

    @StateObject var otpVM = OTPViewModel()
    @FocusState private var isFocused: Bool

    private var otpBinding: Binding<String> {
        Binding(
            get: { otpVM.otpText },
            set: { otpVM.updateOTP($0) }
        )
    }

    var body: some View {

        VStack(spacing: 25) {

            // OTP Boxes
            HStack(spacing: 12) {
                ForEach(0..<otpVM.maxLength, id: \.self) { index in
                    OTPDigitBox(
                        digit: digit(at: index),
                        isActive: otpVM.otpText.count == index,
                        isFilled: index < otpVM.otpText.count
                    )
                }
            }

            // Hidden TextField
            TextField("", text: otpBinding)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode) // SMS Autofill
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)

            // Timer UI
            Text(timerText)
                .font(.footnote)
                .foregroundStyle(.gray)

        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { otpVM.startTimer() }
        .onChangeCompat(of: otpVM.otpText) { newValue in
            if newValue.count == otpVM.maxLength {
                isFocused = false
                verifyOTP()
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < otpVM.otpText.count else { return "" }
        let string = otpVM.otpText
        let i = string.index(string.startIndex, offsetBy: index)
        return String(string[i])
    }

    private var timerText: String {
        switch otpVM.state {
        case .counting:
            return "Resend in \(otpVM.remainingSeconds)s"
        case .expired:
            return "Resend OTP"
        case .idle:
            return ""
        }
    }

    private func verifyOTP() {
        SecureLogger.log("OTP validation triggered") // TODO: - call API here
    }
}
