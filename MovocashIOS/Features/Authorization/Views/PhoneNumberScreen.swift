//
//  PhoneNumberScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

enum PhoneFlowType : String {
    case login = "login"
    case getStarted = "registration"
}

struct PhoneNumberScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @State private var displayText: String = ""
    @State private var previousText: String = ""
    let flowType: PhoneFlowType
    
    init(flowType: PhoneFlowType) {
        self.flowType = flowType
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    BackButton {
                        UIApplication.shared.dismissKeyboard()
                        appState.flow = .choice
                    }
                    Spacer()
                }
                
                Text("Tell us your mobile number")
                    .font(.largeTitle.bold())
                
                Text("We'll text you a code so we can confirm that it's you.")
                    .font(.headline.bold())
                
                HStack {
                    Text("+1")
                        .font(.title3)
                    
                    TextField("(123) 456-7890", text: $displayText)
                        .keyboardType(.numberPad)
                        .font(.title3)
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
                            
                            authVM.phoneNumber = digits
                            previousText = formatted
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                PrimaryButton(title: "Proceed") {
                    UIApplication.shared.dismissKeyboard()
                    let phone = PhoneNumberValidator.sanitize(authVM.phoneNumber)
                    
                    guard PhoneNumberValidator.isValidUSNumber(phone) else {
                        AlertManager.shared.showError("Enter a valid phone number")
                        return
                    }
                    
                    let normalized = PhoneNumberValidator.normalize(phone)
                    
                    authVM.phoneNumber = normalized
                    authVM.context = appState.context
                    
                    Task {
                        do {
                            try await authVM.sendOTP()
                            appState.flow = .otp
                        } catch {
                            AlertManager.shared.showError(error.localizedDescription)
                        }
                    }
                }
            }
            .padding()
            
            if authVM.state == .loading {
                SpinnerView()
            }
        }
        .onAppear() {
            appState.context = flowType.rawValue
        }
    }
}
