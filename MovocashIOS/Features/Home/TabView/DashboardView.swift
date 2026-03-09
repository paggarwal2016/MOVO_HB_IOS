//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    
    @StateObject private var ackVM = AppContainer.shared.makeACHViewModel()
        
    var body: some View {
        VStack(spacing: 0) {
            
            UserHeaderView()
            
            Text("Home")
                .font(.largeTitle)
                .bold()
            Text("Welcome to the app!")
            Spacer()
            
            PrimaryButton(title: "Connect Bank", backgroundColor: .gray) {
                Task {
                    do {
                        let token = try await ackVM.fetchLinkToken()
                        print(token)
                    } catch {
                        print(error)
                    }
                }
            }
                        
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
