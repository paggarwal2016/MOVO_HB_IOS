//
//  PhoneInputView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 23/02/26.
//

import SwiftUI

struct PhoneInputView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showError: Bool = false
    
    @State private var displayText: String = ""
    @State private var rawPhone: String = ""
    @State private var previousText: String = ""
    
    @FocusState private var isFocused: Bool
    
    init(network: NetworkClient = .shared) {
        _viewModel = StateObject(
            wrappedValue: AuthViewModel(network: network)
        )
    }
    
    var body: some View {
        NavigationStack {
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
                            
                            TextField("(123) 456-7890", text: $displayText)
                                .keyboardType(.numberPad)
                                .font(.title3)
                                .focused($isFocused)
                                .onChangeCompat(of: displayText) { newValue in

                                    let isDeleting = newValue.count < previousText.count
                                    var digits = PhoneFormatter.raw(newValue)

                                    // HARD LIMIT — block typing after 10 digits
                                    if digits.count > 10 {
                                        displayText = previousText
                                        return
                                    }

                                    // deleting formatting character fix
                                    if isDeleting && PhoneFormatter.raw(previousText) == digits {
                                        digits = String(digits.dropLast())
                                    }

                                    let formatted = PhoneFormatter.formatted(digits)

                                    displayText = formatted

                                    rawPhone = digits
                                    previousText = formatted
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
                        isFocused = false
                        guard rawPhone.count == 10 else {
                            AlertManager.shared.showError("Enter valid 10 digit mobile number")
                            return
                        }
                        viewModel.sendOTP(phone: "+1\(rawPhone)", context: "registration")
                    } label: {
                        Text("Next")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
                .navigationDestinationCompat(isPresented: $viewModel.showOTP) {
                    OTPVerificationView(authVM: viewModel, phoneNumber: "+1\(rawPhone)", context: "registration")
                        //.sensitiveScreen()
                }
                
                if viewModel.state == .loading {
                    SpinnerView()
                }
            }
            .onAppear {
                displayText = ""
                rawPhone = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
            .navigationTitle("Movo Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    PhoneInputView()
}
