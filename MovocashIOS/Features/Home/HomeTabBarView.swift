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
        case .accounts: return "Pay Anyone"
        case .profile:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .accounts: return "person.2"
        case .profile:  return "gearshape"
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
    @State private var hasLoadedOnce = false

    @SwiftUI.Environment(\.scenePhase) private var scenePhase

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
            guard !hasLoadedOnce else { return }
            hasLoadedOnce = true
            await dashboardVM.fetchDashboard()
            await vCardVM.loadCards(primaryAccountId: dashboardVM.primaryAccount?.id)
        }
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            dashboardVM.cancelAllTasks()
            linkAccountVM.cancelAllTasks()
            vCardVM.cancelAllTasks()
            selectedTab = .home
        }
        .onChange(of: selectedTab) { newTab in
            guard newTab == .home else { return }
            Task {
                await dashboardVM.refreshIfStale(within: 15)
                await vCardVM.loadCards(primaryAccountId: dashboardVM.primaryAccount?.id)
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, dashboardVM.dashboard != nil else { return }
            Task {
                await dashboardVM.refreshIfStale(within: 60)
                await vCardVM.loadCards(primaryAccountId: dashboardVM.primaryAccount?.id)
            }
        }
    }
}


// MARK: - Skeleton Screen

private extension HomeTabBarView {

    var skeletonScreen: some View {
        ZStack {
            MovoBackground()

            VStack(spacing: 0) {
                skeletonHeader
                ScrollView(showsIndicators: false) {
                    skeletonBody
                }
            }
        }
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
                .padding(.horizontal, Spacing.lg)
        }
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
        .toolbarColorScheme(.dark, for: .tabBar)
        .environment(\.symbolVariants, .none)
    }

    @ViewBuilder
    func tabContent(for tab: Tab) -> some View {
        NavigationStack {
            destination(for: tab)
        }
        .tabItem {
            Label(tabLabel(for: tab), systemImage: tab.icon)
                .environment(\.symbolVariants, SymbolVariants.none)
        }
        .tag(tab)
    }

    @ViewBuilder
    func destination(for tab: Tab) -> some View {
        switch tab {
        case .home:     DashboardView(container: container, dashboardVM: dashboardVM, vm: vCardVM)
        case .accounts: PayAnyoneView(container: container, selectedTab: $selectedTab, cards: vCardVM.apiCards, primaryLinkedCard: dashboardVM.primaryLinkedCard)
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
        VStack(spacing: Spacing.xxl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(Color.movo.warning)

            Text(message)
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)
            
            Button(action: {
                isLoggingOut = true
                Task {
                    await sessionManager.logout(appState: appState)
                    lockManager.logout()
                    isLoggingOut = false
                }
            } ) {
                Text("Log Out")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MovoBackground())
    }
}
