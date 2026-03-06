//
//  UserHeaderView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct UserHeaderView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    
    var body: some View {
        ZStack {
            
            VStack(alignment: .leading, spacing: 8) {
                
                HStack {
                    
                    VStack(alignment: .leading) {
                        Text("Good Morning 👋")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Test")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Image(systemName: "arrow.backward.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                Text("Total Balance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("$12,540.00")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
            }
            .padding()
        }
        .frame(height: 180)
        .clipShape(
            RoundedCorner(radius: 30, corners: [.bottomLeft, .bottomRight])
        )
        .background(AppColors.primary)
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {
                showLogoutAlert = false
            }
            Button("Logout", role: .destructive) {
                Task {
                    await AppContainer.shared.sessionManager.logout(appState: appState)
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
}
