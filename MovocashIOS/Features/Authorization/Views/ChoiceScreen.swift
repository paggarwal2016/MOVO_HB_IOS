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
                          backgroundColor: AppColors.secondary,
                          textColor: .black) {
                appState.flow = .loginPhone
            }
        }
        .padding()
    }
}

#Preview() {
    ChoiceScreen()
        .environmentObject(AppState())
}
