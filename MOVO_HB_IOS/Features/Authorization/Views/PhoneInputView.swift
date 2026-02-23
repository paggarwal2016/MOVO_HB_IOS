//
//  PhoneInputView.swift
//  MovocashIOS
//
//  Created by Vinu on 23/02/26.
//

import SwiftUI

struct PhoneInputView: View {
    @StateObject var viewModel = AuthViewModel()
    @State private var phoneNumber: String = "9996451385"
    
    var body: some View {
        NavigationView {
            
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
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Text("We will send you a SMS with a verification code.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button {
                        if !phoneNumber.isEmpty {
                            viewModel.sendOTP(phone: "+1\(phoneNumber)", context: "registration")
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
                
                NavigationLink(
                    destination: OTPVerificationView(phone: phoneNumber),
                    isActive: $viewModel.otpSent
                ) {
                    EmptyView()
                }
                
                if viewModel.isLoading {
                    SpinnerView()
                }
            }
            // ✅ Modern Navigation API above iOS 16
            //        .navigationDestination(isPresented: $viewModel.otpSent) {
            //            OTPVerificationView(phone: phoneNumber)
            //        }
        }
    }
}

#Preview {
    PhoneInputView()
}
