//
//  ChoiceScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI
import LocalAuthentication

struct ChoiceScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var lockManager: AppLockManager

    @State private var isBiometricLoading = false
    @State private var showBiometricError = false

    private var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    private var biometricLabel: String {
        switch biometricType {
        case .faceID:   return "Sign in with Face ID"
        case .touchID:  return "Sign in with Touch ID"
        case .opticID:  return "Sign in with Optic ID"
        default:        return "Sign in with Biometrics"
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.open.fill"
        }
    }

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

                Text("Send to Spend")
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

            if RSAKeyManager.shared.keysExist() {
                Button {
                    guard !isBiometricLoading else { return }
                    isBiometricLoading = true
                    Task {
                        let success = await authVM.loginWithBiometric(appState: appState)
                        isBiometricLoading = false
                        if success {
                            // Biometric server auth succeeded — unlock locally so the
                            // AppLock overlay does not immediately re-prompt Face ID.
                            lockManager.unlockAfterRSAAuth()
                        } else {
                            showBiometricError = true
                        }
                    }
                } label: {
                    Group {
                        if isBiometricLoading {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Label(biometricLabel, systemImage: biometricIcon)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(height: 24)
                }
                .disabled(isBiometricLoading)
            }
        }
        .padding()
        .alert("Sign-In Failed", isPresented: $showBiometricError) {
            Button("Use Phone Number") { appState.flow = .loginPhone }
            Button("Try Again") {
                guard !isBiometricLoading else { return }
                isBiometricLoading = true
                Task {
                    let success = await authVM.loginWithBiometric(appState: appState)
                    isBiometricLoading = false
                    if success {
                        lockManager.unlockAfterRSAAuth()
                    } else {
                        showBiometricError = true
                    }
                }
            }
        } message: {
            Text("Biometric sign-in was unsuccessful. You can try again or log in with your phone number.")
        }
    }
}

#Preview() {
    ChoiceScreen()
        .environmentObject(AppState())
}
