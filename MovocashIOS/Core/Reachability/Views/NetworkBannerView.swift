//
//  NetworkBannerView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
//

import SwiftUI

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



struct NetworkMonitorModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @StateObject private var monitor = NetworkMonitor.shared
    
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
            withAnimation {
                appState.networkStatus = status
            }
        }
    }
}
