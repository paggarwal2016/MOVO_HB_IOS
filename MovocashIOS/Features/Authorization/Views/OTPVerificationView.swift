//
//  OTPVerificationView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

struct OTPVerificationView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var showSuccessAlert = false
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var otpVM = OTPViewModel()

    @FocusState private var isFocused: Bool

    var phoneNumber: String
    let context: String

    private var otpBinding: Binding<String> {
        Binding(
            get: { otpVM.otpText },
            set: { otpVM.updateOTP($0) }
        )
    }

    var body: some View {

        ZStack {

            VStack(spacing: 30) {

                // Title
                Text("Enter One-Time Code")
                    .font(.title2.bold())

                // OTP Boxes
                HStack(spacing: 12) {
                    ForEach(0..<otpVM.maxLength, id: \.self) { index in
                        OTPDigitBox(
                            digit: digit(at: index),
                            isActive: otpVM.otpText.count == index && isFocused,
                            isFilled: index < otpVM.otpText.count
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }

                // Hidden TextField (real input engine)
                TextField("", text: otpBinding)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)

                // Verify Button
                Button(action: verifyOTP) {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(otpVM.isValidOTP ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!otpVM.isValidOTP || authVM.state == .loading)

                // Resend Section
                resendSection
            }
            .padding()

            if authVM.state == .loading {
                SpinnerView()
            }
        }
        .onAppear {
            otpVM.startTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onChangeCompat(of: otpVM.otpText) { newValue in
            if newValue.count == otpVM.maxLength {
                isFocused = false
                verifyOTP()
            }
        }
        .onChangeCompat(of: authVM.state) { newState in
            if newState == .verified {
                AlertManager.shared.showConfirmation(
                    title: "Success",
                    message: "OTP verified successfully",
                    onConfirm: {
                        dismiss()
                        authVM.state = .idle
                        authVM.showOTP = false
                    },
                    onCancel: {
                        otpVM.otpText = ""
                        otpVM.state = .expired
                        otpVM.stopTimer()
                    }
                )
            }
        }
    }

    // MARK: - Digit extractor
    private func digit(at index: Int) -> String {
        guard index < otpVM.otpText.count else { return "" }
        let string = otpVM.otpText
        let i = string.index(string.startIndex, offsetBy: index)
        return String(string[i])
    }

    // MARK: - Resend Section
    @ViewBuilder
    private var resendSection: some View {
        if otpVM.state == .expired {
            Button("Request new code") {
                otpVM.otpText = ""
                isFocused = true
                authVM.sendOTP(phone: phoneNumber, context: context)
                otpVM.startTimer()
            }
            .disabled(authVM.state == .loading)
        } else {
            Text("Request new code (\(otpVM.remainingSeconds)s)")
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Verify OTP
    private func verifyOTP() {
        guard otpVM.isValidOTP else { return }
        authVM.validateOTP(phone: phoneNumber, code: otpVM.otpText)
    }
}
