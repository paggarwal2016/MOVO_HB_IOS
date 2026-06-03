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
    case quick
    case profile

    static let slots: [Tab] = [.home, .quick, .profile]
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

    static let tabIcons = ["house", "person.2", "gearshape"]

    var resolvedTabs: [Tab] {
        let count = dashboardVM.menuItems.count
        guard count > 0 else { return Tab.slots }
        return Array(Tab.slots.prefix(count))
    }

    func tabLabel(at index: Int) -> String {
        guard index >= 0, index < dashboardVM.menuItems.count else { return "" }
        return dashboardVM.menuItems[index].label
    }

    func tabIcon(at index: Int) -> String {
        guard index >= 0, index < Self.tabIcons.count else { return "circle" }
        return Self.tabIcons[index]
    }

    var realTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(resolvedTabs.enumerated()), id: \.element) { index, tab in
                tabContent(for: tab, at: index)
            }
        }
        .tint(Color.movo.accent)
        .toolbarColorScheme(.dark, for: .tabBar)
        .environment(\.symbolVariants, .none)
    }

    @ViewBuilder
    func tabContent(for tab: Tab, at index: Int) -> some View {
        NavigationStack {
            destination(at: index)
        }
        .tabItem {
            Label(tabLabel(at: index), systemImage: tabIcon(at: index))
                .environment(\.symbolVariants, SymbolVariants.none)
        }
        .tag(tab)
    }

    /// Destination screen for the tab at the given position. The screen title is
    /// the API-driven label for that slot.
    @ViewBuilder
    func destination(at index: Int) -> some View {
        let title = tabLabel(at: index)
        switch index {
        case 0:
            DashboardView(container: container, dashboardVM: dashboardVM, vm: vCardVM, selectedTab: $selectedTab, screenTitle: title)
        case 1:
            PayAnyoneView(container: container, selectedTab: $selectedTab, cards: dashboardVM.apiCards, primaryLinkedCard: dashboardVM.primaryLinkedCard, screenTitle: title)
        case 2:
            ProfileScreen(container: container, dashboardVM: dashboardVM, achVM: linkAccountVM, screenTitle: title)
        default:
            EmptyView()
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
