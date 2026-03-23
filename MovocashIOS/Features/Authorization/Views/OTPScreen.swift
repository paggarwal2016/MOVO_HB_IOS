//
//  OTPScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct OTPScreen: View {
    @EnvironmentObject var appState: AppState
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var otpVM = OTPViewModel()
    @FocusState private var isFocused: Bool
    
    private var otpBinding: Binding<String> {
        Binding(
            get: { otpVM.otpText },
            set: { otpVM.updateOTP($0) }
        )
    }
    
    var body: some View {
        
        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    BackButton {
                        UIApplication.shared.dismissKeyboard()
                        appState.flow = .loginPhone
                    }
                    Spacer()
                }
                
                Text("Enter 6-digit code")
                    .font(.largeTitle.bold())
                
                Text("We Sent a verfication code to your mobile \(authVM.phoneNumber.suffix(4))")
                    .font(.headline.bold())
                
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
                
                Spacer()
                
                PrimaryButton(title: "Continue", isEnabled: otpVM.isValidOTP) {
                    UIApplication.shared.dismissKeyboard()
                    Task {
                        await otpVM.submitOTP { code in
                            await authVM.completeOTPVerification(code: code, appState: appState) { destination in
                                appState.otpVerified = true
                                appState.flow = destination
                            }
                        }
                    }
                }
                .disabled(!otpVM.isValidOTP || authVM.state == .loading)
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
                UIApplication.shared.dismissKeyboard()
                Task {
                    await otpVM.submitOTP { code in
                        await authVM.completeOTPVerification(code: code, appState: appState) { destination in
                            appState.otpVerified = true
                            appState.flow = destination
                        }
                    }
                }
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
    
}
