//
//  HomeTabBarView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct HomeTabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var selectedTab = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            
            NavigationStack {
                AccountsView()
            }
            .tabItem {
                Label("Send Money", systemImage: "creditcard.fill")
            }
            .tag(1)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Contact", systemImage: "person.fill")
            }
            .tag(2)
        }
        .tint(AppColors.primary) // Active tab color
        .task {
//            if !RSAKeyManager.isRegistered() { // TODO: - Testing checking
//                UserDefaults.standard.set(false, forKey: "rsa_enrolled")
//                await authVM.enrollRSASilently(appState: appState)
//            }
        }
    }
}
