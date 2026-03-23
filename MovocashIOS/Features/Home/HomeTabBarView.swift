//
//  HomeTabBarView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

enum Tab: Hashable {
    case home
    case accounts
    case contact
    case profile
}

struct HomeTabBarView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTab: Tab = .home
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: Home
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            
            // MARK: Accounts
            NavigationStack {
                AccountsView()
            }
            .tabItem {
                Label("Send Money", systemImage: "creditcard.fill")
            }
            .tag(Tab.accounts)
            
            
            // MARK: Contact
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Contact", systemImage: "gearshape.fill")
            }
            .tag(Tab.contact)
            
            
            // MARK: Profile
            NavigationStack {
                UserProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(Tab.profile)
        }
        .tint(AppColors.primary)
        .onAppear {
            // New user just landed on home after completing registration.
            // Clear the flag and reset any spurious lock from KYC UIViewController teardown.
            if appState.isNewRegistration {
                AppContainer.lockManager.resetToUnlocked()
                appState.isNewRegistration = false
            }
        }
        .task {
           await authVM.enrollRSASilently(appState: appState)
        }
    }
}
