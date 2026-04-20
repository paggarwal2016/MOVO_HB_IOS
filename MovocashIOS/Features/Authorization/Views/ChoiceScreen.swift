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
        VStack(spacing: 25) {
                        
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: -10)
            
            VStack(alignment: .center, spacing: 10) {
                Text("Welcome to MovoCash")
                    .titleStyle()
                
                Text("Send to spend")
                    .subtitleStyle()
                
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            
            PrimaryButton(title: "Get Started") {
                appState.flow = .getStartedPhone
            }

            PrimaryButton(title: "Login",
                          backgroundColor: Color.secondary,
                          textColor: .black) {
                appState.flow = .loginPhone
            }

//            if RSAKeyManager.shared.keysExist() {
//                Button {
//                    Task { await authVM.loginWithBiometric(appState: appState) }
//                } label: {
//                    Label("Sign in with Face ID", systemImage: "faceid")
//                        .font(.subheadline.bold())
//                        .foregroundStyle(.primary)
//                }
//            }
        }
        .padding()
    }
}

#Preview() {
    ChoiceScreen()
        .environmentObject(AppState())
}
