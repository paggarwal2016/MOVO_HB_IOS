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
    @StateObject private var authVM = AuthViewModel()
    @State private var displayText: String = ""
    @State private var rawPhone: String = ""
    @State private var previousText: String = ""
    let flowType: PhoneFlowType
    
    init(flowType: PhoneFlowType, network: NetworkClient = .shared) {
        self.flowType = flowType
        _authVM = StateObject(
            wrappedValue: AuthViewModel(network: network)
        )
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
                            
                            rawPhone = digits
                            previousText = formatted
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                PrimaryButton(title: "Proceed") {
                    UIApplication.shared.dismissKeyboard()
                    guard rawPhone.count == 10 else {
                        AlertManager.shared.showError("Enter valid 10 digit mobile number")
                        return
                    }
                    Task {
                        do {
                            try await authVM.sendOTP(phone: "+1\(rawPhone)", context: appState.context)
                            appState.phoneNumber = "+1\(rawPhone)"
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
