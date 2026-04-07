//
//  PickDocumentView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 07/04/26.
//

import SwiftUI
import UIKit

struct PickDocumentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var sessionManager: SessionManager
    
    var onBack: () -> Void
    var onContinue: () -> Void
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Top bar ────────────────────────────────────────────────
                HStack {
                    BackButton {
                        //TODO: Future Implementation will check below code logic
                        Task {
                            lockManager.logout()
                            await sessionManager.logout(appState: appState)
                            appState.flow = .getStartedPhone
                        }
                    }
                    Spacer()
                }
                Spacer()
                
                // ── Icon ───────────────────────────────────────────────────
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Color.primary)
                    .padding(.bottom, 32)
                
                // ── Title ──────────────────────────────────────────────────
                Text("Verify Your Identity")
                    .font(.title2.bold())
                    .padding(.bottom, 12)
                
                // ── Subtitle ───────────────────────────────────────────────
                Text("Pick a document to verify your identity. Make sure it's valid and clearly readable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer().frame(height: 40)
                
                // ── Document options ───────────────────────────────────────
                VStack(spacing: 12) {
                    DocumentOptionRow(icon: "car", title: "Driver's License")
                    DocumentOptionRow(icon: "globe", title: "Passport")
                    DocumentOptionRow(icon: "creditcard", title: "National ID")
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                PrimaryButton(title: "Continue") {
                    onContinue()
                }
            }
            .padding()
        }
    }
}

// MARK: - DocumentOptionRow

private struct DocumentOptionRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.primary)
                .frame(width: 32)
            
            Text(title)
                .font(.body)
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.primary.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedCorner(radius: 12))
    }
}
