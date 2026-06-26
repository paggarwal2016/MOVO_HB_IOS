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
    
    @AppStorage("hasCompletedSignup") private var hasCompletedSignup = false

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
        ZStack {
            MovoBackground()
            AmbientGlowView()
            
            VStack(spacing: 0) {
                
                Spacer(minLength: 0)
                
                hero
                    .padding(.horizontal, Spacing.xxl + 8)
                
                Spacer(minLength: 0)
                
                actionStack
                    .padding(.horizontal, Spacing.xxl + 4)
                    .padding(.bottom, Spacing.lg)
                
                disclaimer
                    .padding(.horizontal, Spacing.xxl + 4)
                    .padding(.bottom, Spacing.xl + 8)
            }
        }
        .background(Color.movo.background)
        .alert("Sign-In Failed", isPresented: $showBiometricError) {
            Button("Use Phone Number") { appState.flow = .loginPhone }
            Button("Try Again") {
                guard !isBiometricLoading else { return }
                isBiometricLoading = true
                Task {
                    let success = await authVM.loginWithBiometric(appState: appState)
                    isBiometricLoading = false
                    if !success {
                        showBiometricError = true
                    }
                }
            }
        } message: {
            Text("Biometric sign-in was unsuccessful. You can try again or log in with your phone number.")
        }
    }
    
    
    private var hero: some View {
        VStack(spacing: 0) {
            
            // Logo block
            VStack(spacing: Spacing.xxl) {
                MovoMVSymbol()
                    .frame(width: 110, height: 110)
                
                Text("MOVOCASH")
                    .font(.system(size: 22, weight: .regular))
                    .tracking(8.8) // 0.4em at 22pt
                    .foregroundColor(Color.movo.textPrimary)
                    .padding(.leading, 8.8) // optical centering for tracked text
            }
            .padding(.bottom, Spacing.huge + 16)
            
            // Welcome copy
            VStack(spacing: 10) {
                Text("Welcome to MovoCash")
                    .textStyle(Typography.balance)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Send to Spend.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var actionStack: some View {
        VStack(spacing: Spacing.md) {
            
//            if hasCompletedSignup {
//                Button("Get Started") { appState.flow = .getStartedPhone }.buttonStyle(OutlineButtonStyle())
//                Button("Log In") { appState.flow = .loginPhone }.buttonStyle(MovoPrimaryButtonStyle())
//            } else {
//                Button("Get Started") { appState.flow = .getStartedPhone }.buttonStyle(MovoPrimaryButtonStyle())
//                Button("Log In") { appState.flow = .loginPhone }.buttonStyle(OutlineButtonStyle())
//            }
            
            Button("Accept an Invite") { appState.flow = .enterInviteCode }.buttonStyle(MovoPrimaryButtonStyle())
            
            Button("Log In") { appState.referralCode = ""; appState.flow = .loginPhone }.buttonStyle(MovoPrimaryButtonStyle())
                        
            Button("Join the Waitlist") { appState.referralCode = ""; appState.flow = .waitlist }.buttonStyle(OutlineButtonStyle())
            
            if RSAKeyManager.shared.keysExist() {
                Button {
                    guard !isBiometricLoading else { return }
                    isBiometricLoading = true
                    Task {
                        let success = await authVM.loginWithBiometric(appState: appState)
                        isBiometricLoading = false
                        if !success {
                            showBiometricError = true
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if isBiometricLoading {
                            ProgressView()
                                .tint(Color.movo.accent)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 16, weight: .regular))
                            Text(biometricLabel)
                                .textStyle(Typography.bodyCompact)
                        }
                    }
                    .foregroundStyle(Color.movo.accent)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
                .disabled(isBiometricLoading)
            }
        }
    }
    
    private var disclaimer: some View {
        VStack(spacing: 0) {
            // Banking partner line
            disclaimerText()
                .padding(.bottom, Spacing.sm)
            
            // Hairline divider
            Rectangle()
                .fill(Color.movo.borderStrong)
                .frame(width: 24, height: Stroke.hairline)
                .padding(.bottom, Spacing.sm)
            
            // Terms + Privacy
            legalLine()
        }
        .frame(maxWidth: .infinity)
    }
    
    
    private func disclaimerText() -> some View {
        let intro = Text("MovoCash, ")
            .foregroundColor(Color.movo.textSecondary)
        + Text("Inc. is a financial technology company, ")
            .foregroundColor(Color.movo.textTertiary)
        + Text("Fintech")
            .foregroundColor(Color.movo.textSecondary)
            .fontWeight(.semibold)
        + Text(", not a bank. Depository Banking Services provided by Herring Bank, Member ")
            .foregroundColor(Color.movo.textTertiary)

        let fdic = Text("FDIC")
            .foregroundColor(Color.movo.textSecondary)
            .fontWeight(.semibold)
        + Text(". Learn more by visiting ")
            .foregroundColor(Color.movo.textTertiary)

        let outro = Text("Herring Bank")
            .foregroundColor(Color.movo.textSecondary)
            .underline(true, color: Color.movo.borderStrong)
        + Text(". The MOVO Debit Mastercard®️ is issued by Herring Bank, pursuant to licensing by Mastercard International.")
            .foregroundColor(Color.movo.textTertiary)

        return (intro + fdic + outro)
            .font(.system(size: 9.5, weight: .regular))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .onTapGesture {
                if let url = URL(string: "https://www.herringbank.com") {
                    UIApplication.shared.open(url)
                }
            }
    }
    
    
    private func legalLine() -> some View {
        HStack(spacing: 0) {
            Text("Certain terms and conditions may apply. Terms may vary by applicant and are subject to change.")
                .foregroundColor(Color.movo.textSecondary)
        }
        .font(.system(size: 9, weight: .regular))
        .multilineTextAlignment(.center)
    }
}
