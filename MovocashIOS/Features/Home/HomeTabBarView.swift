//
//  HomeTabBarView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

// MARK: - Tab Definition

enum Tab: Hashable {
    case home
    case accounts
    case profile
    
    var label: String {
        switch self {
        case .home:     return "Home"
        case .accounts: return "Send Money"
        case .profile:  return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .accounts: return "creditcard.fill"
        case .profile:  return "gearshape.fill"
        }
    }
}


// MARK: - Appearance Setup

enum TabBarAppearance {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}


// MARK: - Main Tab View

struct HomeTabBarView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userVM: UserViewModel
    
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            tabContent(for: .home)
            tabContent(for: .accounts)
            tabContent(for: .profile)
        }
        .tint(AppColors.primary)
        .onAppear(perform: handleOnAppear)
        .task { await handleOnTask() }
    }
}


// MARK: - Tab Content Builder

private extension HomeTabBarView {
    
    @ViewBuilder
    func tabContent(for tab: Tab) -> some View {
        NavigationStack {
            destination(for: tab)
        }
        .tabItem {
            Label(tab.label, systemImage: tab.icon)
        }
        .tag(tab)
    }
    
    @ViewBuilder
    func destination(for tab: Tab) -> some View {
        switch tab {
        case .home:     DashboardView()
        case .accounts: AccountsView()
        case .profile:  UserProfileView()
        }
    }
}


// MARK: - Side Effects

private extension HomeTabBarView {
    
    func handleOnAppear() {
        guard appState.isNewRegistration else { return }
        AppContainer.lockManager.resetToUnlocked()
        appState.isNewRegistration = false
    }
    
    func handleOnTask() async {
        await userVM.fetchProfile()
        guard !RSAKeyManager.isRegistered() else { return }
        await authVM.enrollRSASilently(appState: appState)
    }
}
