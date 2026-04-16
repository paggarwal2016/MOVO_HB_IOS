//
//  ChoiceScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct ChoiceScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(spacing: 40) {
            Text("Welcome to MovoCash")
                .font(.title)
                .bold()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            PrimaryButton(title: "Get Started") {
                appState.flow = .getStartedPhone
            }

            PrimaryButton(title: "Login",
                          backgroundColor: Color.secondary,
                          textColor: .black) {
                appState.flow = .loginPhone
            }

            // Show biometric login only when RSA keys are already enrolled
            if RSAKeyManager.shared.keysExist() {
                Button {
                    Task { await authVM.loginWithBiometric(appState: appState) }
                } label: {
                    Label("Sign in with Face ID", systemImage: "faceid")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
    }
}

#Preview() {
    ChoiceScreen()
        .environmentObject(AppState())
}
