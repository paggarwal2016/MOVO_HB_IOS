//
//  SignUpScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/04/26.
//

import SwiftUI

struct SignUpScreen: View {
    @StateObject private var vm = SignUpViewModel()
    @FocusState private var emailFocused: Bool

    let onBack: () -> Void
    let onContinue: (String) -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    BackButton { onBack() }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Please enter your email")
                        .titleStyle()
                    Text("We'll send a verification code to confirm it's you.")
                        .subtitleStyle()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email address")
                        .font(.subheadline)
                        .foregroundColor(.secTcolor)
                    TextField("Enter your email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .focused($emailFocused)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(emailFocused ? Color.primary : Color(.systemGray4), lineWidth: 1.5)
                        )
                }

                Spacer()

                PrimaryButton(title: "Send code", isEnabled: vm.isValid) {
                    UIApplication.shared.dismissKeyboard()
                    onContinue(vm.email)
                }
                .disabled(!vm.isValid)
            }
            .padding()
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { emailFocused = true }
        }
    }
}
