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

/// Selection identity + local icon for a bottom tab bar slot.
///
/// The set, order, and labels of the tabs come entirely from the MENU section of
/// the dashboard API. Each menu item's `action` decides which screen + icon it
/// maps to (NOT its position) — so the API can rename a tab's `label` freely
/// without changing where it goes, and reorder tabs without breaking routing.
/// An unrecognized `action` becomes `.other(action)` so it still renders with a
/// placeholder. The app owns only the icon — the label always comes from the API.
enum Tab: Hashable {
    case home
    case payAnyone
    case quickPay
    case profile
    case other(String)

    /// Maps an API menu `action` to a known tab. Action values are the stable
    /// routing key (`label` is display-only), so unknown actions fall through to
    /// `.other` and render a placeholder rather than guessing by position.
    init(action: String) {
        switch action {
        case "Home":     self = .home
        case "Movo-Pay": self = .payAnyone
        case "Settings": self = .profile
        default:         self = .other(action)
        }
    }

    /// Local SF Symbol for the slot.
    /// .home uses this only as a fallback if the UIImage rasteriser hasn't fired yet;
    /// the real Home icon is MovoMVSymbol rendered via ImageRenderer.
    var icon: String {
        switch self {
        case .home:      return "house"                    // fallback — M rendered via UIImage
        case .payAnyone: return "bolt.fill"
        case .quickPay:  return "bolt.fill"
        case .profile:   return "person.crop.circle.fill"
        case .other:     return "square.dashed"
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

    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme)  private var colorScheme

    @State private var selectedTab: Tab = .home
    @State private var isLoggingOut = false
    @State private var hasLoadedOnce = false
    /// Rasterised MovoMVSymbol images — cached so ImageRenderer never runs during body.
    @State private var homeIconSelected:   UIImage?
    @State private var homeIconUnselected: UIImage?

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
        .onAppear {
            handleOnAppear()
            refreshHomeIcons()
        }
        .onChange(of: displayScale)  { _ in refreshHomeIcons() }
        .onChange(of: colorScheme)   { _ in refreshHomeIcons() }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            dashboardVM.cancelAllTasks()
            linkAccountVM.cancelAllTasks()
            vCardVM.cancelAllTasks()
            selectedTab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            // Land on the dashboard tab (covers the profile-originated flows).
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
                skeletonTabBar
            }
        }
    }

    // MARK: Tab bar

    /// Placeholder bottom tab bar shown while the dashboard loads, so the real
    /// tab bar doesn't pop in once `realTabView` appears. The item count is a
    /// best-guess placeholder; the live tab bar is API-driven.
    var skeletonTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.movo.border)
                .frame(height: Stroke.hairline)

            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.movo.elevated)
                            .frame(width: 26, height: 26)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.movo.elevated)
                            .frame(width: 38, height: 7)
                            .shimmer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
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

    /// Tabs to render — one per API MENU item, in API order. Each item maps to a
    /// tab by its `action` (icon + destination); an unrecognized action renders as
    /// `.other` with a placeholder. Nothing is capped: the menu is exactly what the
    /// API returns.
    var resolvedTabs: [Tab] {
        dashboardVM.menuItems.map { Tab(action: $0.action) }
    }

    /// API-driven label for the tab at the given position. The name always comes
    /// from the API — never hardcoded.
    func tabLabel(at index: Int) -> String {
        guard index >= 0, index < dashboardVM.menuItems.count else { return "" }
        return dashboardVM.menuItems[index].label
    }

    var realTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(resolvedTabs.enumerated()), id: \.offset) { index, tab in
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
            destination(for: tab, title: tabLabel(at: index))
        }
        .tabItem {
            let label = tabLabel(at: index)
            if tab == .home,
               let img = selectedTab == .home ? homeIconSelected : homeIconUnselected {
                // MovoMVSymbol rasterised to UIImage — .alwaysOriginal preserves two-tone colors.
                Label { Text(label) } icon: { Image(uiImage: img) }
            } else {
                Label(label, systemImage: tab.icon)
                    .environment(\.symbolVariants, SymbolVariants.none)
            }
        }
        .tag(tab)
    }

    /// Destination for a tab. Slots without a dedicated screen (Quick Pay and any
    /// unmapped/extra menu item) render a placeholder until wired to a real screen.
    @ViewBuilder
    func destination(for tab: Tab, title: String) -> some View {
        switch tab {
        case .home:
            DashboardView(container: container, dashboardVM: dashboardVM, vm: vCardVM, selectedTab: $selectedTab, screenTitle: title)
        case .payAnyone:
            PayAnyoneView(container: container, selectedTab: $selectedTab, cards: dashboardVM.apiCards, primaryLinkedCard: dashboardVM.primaryLinkedCard, screenTitle: title)
        case .profile:
            ProfileScreen(container: container, dashboardVM: dashboardVM, achVM: linkAccountVM, screenTitle: title)
        case .quickPay, .other:
            placeholderTab(title: title)
        }
    }

    /// Placeholder shown for a menu slot that has no dedicated screen yet.
    @ViewBuilder
    func placeholderTab(title: String) -> some View {
        ZStack {
            MovoBackground()
            VStack(spacing: Spacing.md) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(Color.movo.textSecondary)
                Text(title)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textSecondary)
            }
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

    // MARK: Home tab icon rasteriser

    /// Renders MovoMVSymbol at the current display scale into a UIImage.
    /// Must be called from the main actor (ImageRenderer requires it).
    /// Returns nil only if ImageRenderer produces no output (should not happen in practice).
    func makeHomeIcon(selected: Bool, scale: CGFloat, scheme: ColorScheme) -> UIImage? {
        let unselected: Color = scheme == .dark ? .white : .black
        let body    = selected ? Color.movo.accent : unselected
        let chevron = selected ? Color.movo.accent : unselected
        // .environment(\.colorScheme) forces ImageRenderer (which defaults to light)
        // to resolve dynamic colors (secondaryLabel, movo tokens) in the correct scheme.
        let view = MovoMVSymbol(bodyStyle: body, accent: chevron)
            .frame(width: 24, height: 24)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        // .alwaysOriginal — never let UIKit recolor the image (preserves two-tone M).
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }

    /// Re-renders both states and caches them. Call on appear and on
    /// displayScale / colorScheme change so the raster stays correct.
    func refreshHomeIcons() {
        // Use UITraitCollection.current instead of @Environment(\.colorScheme) —
        // .toolbarColorScheme(.dark, for: .tabBar) forces the SwiftUI env to .dark
        // even on a light-mode device, which would make the unselected M render white in light mode.
        let deviceScheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        homeIconSelected   = makeHomeIcon(selected: true,  scale: displayScale, scheme: deviceScheme)
        homeIconUnselected = makeHomeIcon(selected: false, scale: displayScale, scheme: deviceScheme)
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
