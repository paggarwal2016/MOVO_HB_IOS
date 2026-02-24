//
//  OTPVerificationView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

struct OTPVerificationView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AuthViewModel
    //@StateObject private var kycVM = KycViewModel() // TODO: - Enable after the New SDK is released
    var phone: String
    @State private var code: String = ""
    @FocusState private var isFocused: Bool
    @State private var showTokenAlert: Bool = false
            
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                
                Text("Verify your\nphone number")
                    .font(.largeTitle.bold())
                
                Text("Enter the 6-digit code sent to you at +1 \(phone)")
                    .foregroundColor(.gray)
                
                OTPTextField(code: $code)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .padding(.vertical, 30)
                
                Button("Resend code via SMS") {
                    print("Resend tapped")
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Button {
                    viewModel.validateOTP(phone: phone, code: code)
                } label: {
                    Text("Done")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(code.count == 6 ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(code.count != 6)
            }
            .padding()
            .onAppear {
                isFocused = true
            }
            if viewModel.isLoading {
                SpinnerView()
            }
        }
        .onChange(of: viewModel.kycProcess) { newValue in
            if newValue {
                showTokenAlert = true
//                DispatchQueue.main.async {
//                    kycVM.startKyc() // TODO: - Enable after the New SDK is released
//                }
            }
        }
        .alert("Token received", isPresented: $showTokenAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your authentication token was successfully received.")
        }
    }
}
