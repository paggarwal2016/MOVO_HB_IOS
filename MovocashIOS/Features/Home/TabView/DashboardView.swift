//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/03/26.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    @StateObject private var ackVM = ACHViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            
            UserHeaderView()
            
            Text("Home")
                .font(.largeTitle)
                .bold()
            Text("Welcome to the app!")
            Spacer()
            
            PrimaryButton(title: "Get Link Token", backgroundColor: AppColors.secondary) {
                Task {
                    do {
                        try await ackVM.fetchLinkToken()
                    } catch {
                        AlertManager.shared.showError(error.localizedDescription)
                    }
                }
            }
            .padding()
            
            Spacer()
            
        }
        .background(Color(.systemGroupedBackground))
    }
}
