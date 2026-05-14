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
    @StateObject private var vCardVM: VCardViewModel

    @State private var selectedTab: Tab = .home
    @State private var isLoggingOut = false

    init(container: AppContainer) {
        _dashboardVM = StateObject(wrappedValue: container.makeDashboardViewModel())
        _linkAccountVM = StateObject(wrappedValue: container.makeACHViewModel())
        _vCardVM = StateObject(wrappedValue: container.makeVCardViewModel())
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
        ZStack(alignment: .bottom) {
            MovoBackground()

            VStack(spacing: 0) {
                skeletonHeader
                ScrollView(showsIndicators: false) {
                    skeletonBody
                        .padding(.bottom, 88)
                }
            }

            skeletonTabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Header

    var skeletonHeader: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color.movo.elevated)
                .frame(width: 38, height: 38)
                .shimmer()

            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.movo.elevated)
                    .frame(width: 72, height: 10)
                    .shimmer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.movo.elevated)
                    .frame(width: 128, height: 14)
                    .shimmer()
            }

            Spacer()

            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(Color.movo.elevated)
                .frame(width: 36, height: 36)
                .shimmer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: Body

    var skeletonBody: some View {
        VStack(spacing: Spacing.lg) {
            skeletonBalanceCard
                .padding(.horizontal, Spacing.lg)

            skeletonQuickActions
                .padding(.horizontal, Spacing.lg)

            skeletonFeatureCard(height: 88)
                .padding(.horizontal, Spacing.lg)

            skeletonFeatureCard(height: 88)
                .padding(.horizontal, Spacing.lg)

            skeletonMyCards
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: Balance card

    var skeletonBalanceCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
                .frame(height: 180)

            VStack(alignment: .leading, spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.movo.elevatedHigh)
                    .frame(width: 96, height: 10)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.movo.elevatedHigh)
                    .frame(width: 152, height: 28)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.movo.elevatedHigh)
                    .frame(width: 136, height: 11)
            }
            .padding(Spacing.xl)
            .frame(height: 180, alignment: .leading)
        }
        .shimmer()
        .shadow(color: Color.movo.accentSoft, radius: 24, x: 0, y: 10)
    }

    // MARK: Quick actions

    var skeletonQuickActions: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
                    .frame(height: 52)
                    .shimmer()
            }
        }
    }

    // MARK: Feature cards (Pay Anyone, Linked Accounts)

    func skeletonFeatureCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Radius.heroCard)
            .fill(Color.movo.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
            .frame(height: height)
            .shimmer()
    }

    // MARK: My Cards section

    var skeletonMyCards: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.movo.elevated)
                    .frame(width: 68, height: 10)
                    .shimmer()
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.movo.elevated)
                    .frame(width: 40, height: 10)
                    .shimmer()
            }
            .padding(.horizontal, Spacing.lg)

            CardSkeletonView()
        }
    }

    // MARK: Tab bar

    var skeletonTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Spacer()
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(Color.movo.elevated)
                        .frame(width: 24, height: 24)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.movo.elevated)
                        .frame(width: 44, height: 9)
                        .shimmer()
                }
                Spacer()
            }
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .background(
            Color.movo.surface
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.movo.border)
                        .frame(height: Stroke.hairline)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


// MARK: - Real Tab View

private extension HomeTabBarView {

    var resolvedTabs: [Tab] {
        let mapped = dashboardVM.menuItems.compactMap { Tab(action: $0.action) }
        return mapped.isEmpty ? [.home, .accounts, .profile] : mapped
    }

    func tabLabel(for tab: Tab) -> String {
        dashboardVM.menuItems.first { Tab(action: $0.action) == tab }?.label ?? tab.label
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
            Label(tabLabel(for: tab), systemImage: tab.icon)
        }
        .tag(tab)
    }

    @ViewBuilder
    func destination(for tab: Tab) -> some View {
        switch tab {
        case .home:     DashboardView(container: container, dashboardVM: dashboardVM, linkAccountVM: linkAccountVM, vm: vCardVM)
        case .accounts: PayAnyoneView(container: container, selectedTab: $selectedTab, cards: vCardVM.apiCards, totalBalance: dashboardVM.primaryAccount?.availableBalance ?? 0)
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
