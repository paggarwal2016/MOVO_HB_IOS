//
//  HomeTabBarView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI
import UIKit

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

    // Maps the action string from the MENU section of the dashboard API
    init?(action: String) {
        switch action {
        case "Home":      self = .home
        case "PayAnyone": self = .accounts
        case "Settings":  self = .profile
        default:          return nil
        }
    }
}


// MARK: - Appearance Setup

enum TabBarAppearance {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = MovoTheme.color.background.uiColor
        appearance.shadowColor = MovoTheme.color.accent.uiColor.withAlphaComponent(0.5)

        let selected   = MovoTheme.color.accent.uiColor
        let unselected = MovoTheme.color.textTertiary.uiColor

        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
        appearance.stackedLayoutAppearance.normal.iconColor   = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes   = [.foregroundColor: unselected]

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}


// MARK: - Main Tab View

struct HomeTabBarView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userVM: UserViewModel
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager

    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var linkAccountVM: ACHViewModel

    @State private var selectedTab: Tab = .home
    @State private var isLoggingOut = false

    init(container: AppContainer) {
        _dashboardVM = StateObject(wrappedValue: container.makeDashboardViewModel())
        _linkAccountVM = StateObject(wrappedValue: container.makeACHViewModel())
    }

    var body: some View {
        Group {
            if let message = dashboardVM.supportMessage {
                supportScreen(message: message)
            } else if dashboardVM.dashboard == nil {
                skeletonScreen
            } else {
                realTabView
            }
        }
        .task {
            await dashboardVM.fetchDashboard()
        }
        .onAppear(perform: handleOnAppear)
    }
}


// MARK: - Skeleton Screen

private extension HomeTabBarView {

    var skeletonScreen: some View {
        VStack(spacing: 0) {
            skeletonHeader
            skeletonContent
            Spacer()
            skeletonTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(.systemGroupedBackground))
    }

    var skeletonHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 38, height: 38)
                .shimmer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 14)
                .shimmer()
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 14)
                .shimmer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }

    var skeletonContent: some View {
        VStack(spacing: 16) {
            CardSkeletonView()
                .padding(.top, 16)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 52)
                .shimmer()
                .padding(.horizontal, 15)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 90)
                .shimmer()
                .padding(.horizontal, 15)
        }
    }

    var skeletonTabBar: some View {
        HStack {
            ForEach(0..<3, id: \.self) { _ in
                Spacer()
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 10)
                        .shimmer()
                }
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }
}


// MARK: - Real Tab View

private extension HomeTabBarView {

    var resolvedTabs: [Tab] {
        let mapped = dashboardVM.menuItems.compactMap { Tab(action: $0.action) }
        return mapped.isEmpty ? [.home, .accounts, .profile] : mapped
    }

    var realTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(resolvedTabs, id: \.self) { tab in
                tabContent(for: tab)
            }
        }
        .tint(Color.movo.accent)
        .onAppear { TabBarAppearance.configure() }
    }

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
        case .home:     DashboardView(container: container, dashboardVM: dashboardVM, linkAccountVM: linkAccountVM)
        case .accounts: PayAnyoneView(container: container)
        case .profile:  ProfileScreen(container: container, dashboardVM: dashboardVM, achVM: linkAccountVM)
        }
    }
}


// MARK: - Side Effects

private extension HomeTabBarView {

    func handleOnAppear() {
        guard appState.isNewRegistration else { return }
        lockManager.resetToUnlocked()
        appState.isNewRegistration = false
    }
}


// MARK: - Support Screen

private extension HomeTabBarView {

    @ViewBuilder
    func supportScreen(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PrimaryButton(
                title: "Log Out",
                backgroundColor: .primary,
                textColor: .white,
                isLoading: isLoggingOut
            ) {
                isLoggingOut = true
                Task {
                    await sessionManager.logout(appState: appState)
                    lockManager.logout()
                    isLoggingOut = false
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
