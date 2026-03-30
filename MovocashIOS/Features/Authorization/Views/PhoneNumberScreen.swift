//
//  PhoneNumberScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct PhoneNumberScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
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

                    TextField("(123) 456-7890", text: $authVM.phoneDisplayText)
                        .keyboardType(.numberPad)
                        .font(.title3)
                        .onChangeCompat(of: authVM.phoneDisplayText) { newValue in
                            authVM.handlePhoneInput(newValue)
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                PrimaryButton(title: "Proceed") {
                    UIApplication.shared.dismissKeyboard()
                    Task {
                        await authVM.submitPhoneNumber(appState: appState)
                    }
                }
            }
            .padding()

            if authVM.state == .loading {
                SpinnerView()
            }
        }
        .onAppear() {
            authVM.reset()
            appState.context = flowType
        }
    }
}
