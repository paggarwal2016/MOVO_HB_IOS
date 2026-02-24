//
//  PhoneInputView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

struct PhoneInputView: View {
    @StateObject var viewModel = AuthViewModel(network: NetworkClient())
    @State private var phoneNumber: String = ""
    @State private var showError: Bool = false

    
    var body: some View {
        NavigationStack { // ✅ Use NavigationStack instead of NavigationView
            ZStack {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("What’s your\nphone number?")
                        .font(.largeTitle.bold())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number")
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text("+1")
                                .font(.title3)
                            
                            TextField("xxxxxxxxxx", text: $phoneNumber)
                                .keyboardType(.numberPad)
                                .font(.title3)
                                .onChange(of: phoneNumber) { newValue in
                                    // Keep only digits
                                    phoneNumber = newValue.filter { $0.isNumber }
                                }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if showError {
                        Text("Please enter a valid 10-digit phone number.")
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else {
                        Text("We will send you a SMS with a verification code.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                                        
                    Spacer()
                    
                    Button {
                        if isValidPhone(phoneNumber) {
                            viewModel.sendOTP(phone: "+1\(phoneNumber)", context: "registration")
                        } else {
                            showError = true
                        }
                    } label: {
                        Text("Next")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
                
                // TODO: ios 16
                //                NavigationLink(
                //                    destination: OTPVerificationView(phone: phoneNumber),
                //                    isActive: $viewModel.otpSent
                //                ) {
                //                    EmptyView()
                //                }
                
                // Modern Navigation API for iOS 16+
                .navigationDestination(isPresented: $viewModel.otpSent) {
                    OTPVerificationView(viewModel: viewModel, phone: phoneNumber)
                }
                
                if viewModel.isLoading {
                    SpinnerView()
                }
            }
        }
    }
    
    // MARK: - Phone validation
    private func isValidPhone(_ number: String) -> Bool {
        let phoneRegex = "^[0-9]{10}$"
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: number)
    }
}

#Preview {
    PhoneInputView()
}
