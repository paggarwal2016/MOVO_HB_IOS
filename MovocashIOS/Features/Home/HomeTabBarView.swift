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
        .task {
            //            if !RSAKeyManager.isRegistered() { // TODO: - Testing checking
            //                UserDefaults.standard.set(false, forKey: "rsa_enrolled")
            //                await authVM.enrollRSASilently(appState: appState)
            //            }
        }
    }
}
