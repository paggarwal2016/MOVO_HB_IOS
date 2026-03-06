//
//  NetworkBannerView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import SwiftUI

//MARK: - Network UI
struct NetworkBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            
            Text("No Internet Connection")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(AppColors.primary)
    }
}


//MARK: - Network Modifier
struct NetworkMonitorModifier: ViewModifier {
    
    @ObservedObject var appState: AppState
    @StateObject private var monitor = NetworkMonitor.shared
    @State private var didReceiveInitialStatus = false
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if appState.networkStatus == .disconnected {
                NetworkBannerView()
                    .transition(.move(edge: .top))
                    .zIndex(1)
            }
        }
        .onReceive(monitor.$status) { status in
            if !didReceiveInitialStatus {
                appState.networkStatus = status
                didReceiveInitialStatus = true
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                appState.networkStatus = status
            }
        }
    }
}
