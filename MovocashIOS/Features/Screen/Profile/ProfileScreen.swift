//
//  ProfileScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation
import SwiftUI
import Combine

struct ProfileScreen: View {
    
    @EnvironmentObject var userVM: UserViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject private var authVM: AuthViewModel
    
    @ObservedObject var dashboardVM: DashboardViewModel
    @ObservedObject var achVM: ACHViewModel

    private let container: AppContainer
    /// Title shown in the nav bar — passed from the tab's MENU label.
    private let screenTitle: String

    @State private var isBiometricOn             = false
    @State private var showDisableBiometricAlert = false
    @State private var showBiometricEnrollSheet  = false
    @State private var showSecuritySettings      = false
    @State private var showManageAccounts        = false
    @State private var showDeletedCards          = false
    @State private var isLoggingOut              = false
    @State private var showSignOutAlert          = false
    @State private var showDeleteAlert           = false
    @State private var hasLoadedOnce             = false

    init(container: AppContainer, dashboardVM: DashboardViewModel, achVM: ACHViewModel, screenTitle: String = "Settings") {
        self.container   = container
        self.dashboardVM = dashboardVM
        self.achVM = achVM
        self.screenTitle = screenTitle
    }
    
    private var effectiveBiometricType: BiometricType {
        lockManager.isBiometricAvailable
        ? lockManager.biometricType
        : lockManager.hardwareBiometricType
    }
    
    private var effectiveProfile: UserProfileResponse? {
        dashboardVM.userDetails.map { UserProfileResponse(from: $0) } ?? userVM.profile
    }
    
    private var effectiveAccounts: [ACHAccount] {
        if achVM.hasFetched {
            return achVM.accounts
        }
        return dashboardVM.linkedAccounts?.linkedAccounts ?? achVM.accounts
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            VStack(spacing: 0) {
                Group {
                    if let profile = effectiveProfile {
                        profileContent(profile)
                    } else if userVM.state == .loading {
                        profileSkeleton
                    } else {
                        emptyState
                    }
                }
            }
            StatusBarScrim()
            if isLoggingOut {
                Color.black.opacity(0.45).ignoresSafeArea()
                SpinnerView()
            }
        }
        .task {
            guard !hasLoadedOnce else { return }
            hasLoadedOnce = true
            guard !achVM.hasFetched, dashboardVM.linkedAccounts == nil else { return }
            await achVM.fetchAccounts()
        }
        .onAppear { isBiometricOn = lockManager.isBiometricEnabled }
        .onReceive(lockManager.objectWillChange) {
            Task { @MainActor in isBiometricOn = lockManager.isBiometricEnabled }
        }
    }
}

// MARK: - Profile Content

private extension ProfileScreen {

    // MARK: - Title Bar

    func profileContent(_ profile: UserProfileResponse) -> some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                avatarHeader(profile)
                
                infoCard(title: "PERSONAL INFO") {
                    infoRow(label: "First name", value: profile.firstName ?? "—")
                    cardDivider
                    infoRow(label: "Last name",  value: profile.lastName  ?? "—")
                }
                
                infoCard(title: "CONTACT") {
                    infoRow(label: "Email", value: profile.displayEmail)
                    cardDivider
                    infoRow(label: "Phone", value: profile.displayPhone)
                }
                
                infoCard(title: "ADDRESS") {
                    infoRow(label: "State", value: profile.state ?? "—")
                    cardDivider
                    infoRow(label: "ZIP",   value: profile.zip   ?? "—")
                }
                
                securityCard
                linkedBankCard
//                if !dashboardVM.deletedCards.isEmpty {
//                    Cards
//                }
                signOutButton
                deleteAccountButton
                footerText
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.huge)
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await Task {
                async let profile: () = userVM.refresh()
                async let accounts: () = achVM.refresh()
                _ = await (profile, accounts)
            }.value
        }
        .tint(Color.movo.accent)
        .sheet(isPresented: $showBiometricEnrollSheet, onDismiss: {
            isBiometricOn = lockManager.isBiometricEnabled
        }) {
            BiometricEnrollView(
                lockManager: lockManager,
                onEnable: {
                    // Explicitly hold the toggle ON before closing the sheet so the
                    // onDismiss read of lockManager.isBiometricEnabled never races
                    // against a timing window where the key write hasn't propagated.
                    isBiometricOn = true
                    showBiometricEnrollSheet = false
                    return true
                },
                onSkip: { isBiometricOn = false; showBiometricEnrollSheet = false }
            )
        }
        .alert("Disable \(effectiveBiometricType.displayName)?",
               isPresented: $showDisableBiometricAlert) {
            Button("Disable", role: .destructive) {
                lockManager.revokeBiometricSafely()
                // Clear the per-user Keychain enrollment flag so the next login
                // correctly re-prompts this user to re-enroll biometrics.
                Task { await authVM.clearBiometricEnrollmentForCurrentUser() }
            }
            Button("Cancel",  role: .cancel) { isBiometricOn = true }
        } message: {
            Text("You'll need to re-enroll to use \(effectiveBiometricType.displayName) again.")
        }
        .navigationDestination(isPresented: $showSecuritySettings) {
            SecuritySettingsView(lockManager: lockManager)
        }
        .navigationDestination(isPresented: $showManageAccounts) {
            ManageExternalAccountsView(
                achVM: achVM,
                primaryAccount: dashboardVM.primaryAccount,
                container: container
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(isPresented: $showDeletedCards) {
            DeletedCardsView(cards: dashboardVM.deletedCards)
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                isLoggingOut = true
                Task {
                    await sessionManager.logout(appState: appState)
                    lockManager.logout()
                    isLoggingOut = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll be signed out of your account.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await userVM.deleteAccount()
                    if success {
                        lockManager.logout()
                        await sessionManager.logout(appState: appState)
                        ToastManager.shared.show("Account deleted successfully.",
                                                 style: .success, position: .bottom)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account. This action cannot be undone.")
        }
    }
    
    // MARK: Avatar Header
    
    func avatarHeader(_ profile: UserProfileResponse) -> some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.movo.elevated, Color.movo.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(Circle().strokeBorder(Color.movo.accent, lineWidth: Stroke.hairline))
                if let urlStr = profile.profilePicture,
                   !urlStr.isEmpty,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        initialsLabel(profile.initials)
                    }
                    .clipShape(Circle())
                } else {
                    initialsLabel(profile.initials)
                }
            }
            .frame(width: 72, height: 72)
            .background(
                Circle()
                    .fill(Color.movo.accentSoft)
                    .padding(-4)
            )
            
            VStack(spacing: 4) {
                Text(profile.fullName)
                    .font(Typography.cardTitle.font)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                Text(profile.displayEmail)
                    .font(Typography.caption.font)
                    .foregroundStyle(Color.movo.textTertiary)
            }
            
            HStack(spacing: Spacing.sm) {
                if profile.emailVerified      { verifiedPill("Email verified",  icon: "checkmark")  }
                if profile.smsVerified        { verifiedPill("SMS verified",    icon: "iphone")     }
                if profile.isTwoFactorEnabled { verifiedPill("2FA on",          icon: "lock.fill")  }
            }
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xs)
        .frame(maxWidth: .infinity)
    }
    
    func initialsLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundStyle(Color.movo.accent)
    }
    
    func verifiedPill(_ label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(Typography.eyebrow.font)
        }
        .foregroundStyle(Color.movo.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.movo.accentTint, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
    }
    
    // MARK: Info Card
    
    @ViewBuilder
    func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            eyebrowLabel(title)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
    }
    
    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.subtitle.font)
                .foregroundStyle(Color.movo.textTertiary)
            Spacer()
            Text(value)
                .font(Typography.body.font)
                .foregroundStyle(Color.movo.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.rowPaddingVertical)
        .padding(.horizontal, Spacing.lg)
    }
    
    var cardDivider: some View {
        Divider()
            .background(Color.movo.border)
            .padding(.horizontal, Spacing.lg)
    }
    
    func eyebrowLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.eyebrow.font)
            .foregroundStyle(Color.movo.textTertiary)
            .padding(.leading, Spacing.xs)
    }
    
    // MARK: Security Card
    
    var securityCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            eyebrowLabel("SECURITY")
            HStack(spacing: Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(lockManager.isBiometricHardwarePresent
                              ? (lockManager.isBiometricEnabled
                                 ? Color.movo.accent.opacity(0.18)
                                 : Color.movo.elevated)
                              : Color.movo.elevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: lockManager.isBiometricHardwarePresent
                          ? effectiveBiometricType.systemImageName
                          : "lock.shield.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(lockManager.isBiometricHardwarePresent
                                     ? Color.movo.accent
                                     : Color.movo.textSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(lockManager.isBiometricHardwarePresent
                         ? effectiveBiometricType.displayName
                         : "Security Settings")
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                    Text(lockManager.isBiometricHardwarePresent
                         ? "Use \(effectiveBiometricType.displayName) to log in and authorize payments"
                         : "Passcode & authentication")
                    .font(Typography.subtitle.font)
                    .foregroundStyle(Color.movo.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if lockManager.isBiometricHardwarePresent {
                    Toggle("", isOn: $isBiometricOn)
                        .labelsHidden()
                        .tint(Color.movo.accent)
                        .fixedSize()
                        .allowsHitTesting(false)
                        .onChange(of: isBiometricOn) { newValue in
                            guard newValue != lockManager.isBiometricEnabled else { return }
                            if newValue {
                                showBiometricEnrollSheet = true
                            } else {
                                showDisableBiometricAlert = true
                            }
                        }
                } else {
                    Button { showSecuritySettings = true } label: {
                        MovoChevron(.disclosure, color: Color.movo.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.lg)
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
    }
    
    // MARK: Linked Bank Accounts Card
    
    var linkedBankCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            eyebrowLabel("LINKED BANK ACCOUNTS")
            VStack(spacing: 0) {
                manageExternalAccount
            }
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
    }
    
    var Cards: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            eyebrowLabel("CARDS")
            VStack(spacing: 0) {
                deletedCardsRow
            }
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
    }

    var deletedCardsRow: some View {
        Button {
            showDeletedCards = true
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.movo.elevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.movo.accent)
                }
                Text("Deleted cards")
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                Spacer()
                MovoChevron(.disclosure)
            }
            .padding(.vertical, Spacing.rowPaddingVertical)
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
    }
    
    
    
    var manageExternalAccount: some View {
        Button {
            achVM.seed(accounts: effectiveAccounts)
            showManageAccounts = true
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.movo.elevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.columns")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.movo.accent)
                }
                Text("Manage external account")
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                Spacer()
                MovoChevron(.disclosure)
            }
            .padding(.vertical, Spacing.rowPaddingVertical)
            .padding(.horizontal, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    
    
    // MARK: Bottom Actions
    
    var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack {
                Spacer()
                if isLoggingOut {
                    ProgressView().tint(Color.movo.textPrimary)
                } else {
                    Text("Sign out")
                        .font(Typography.body.font)
                        .foregroundStyle(Color.movo.textPrimary)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.lg)
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
        .buttonStyle(.plain)
        .disabled(isLoggingOut)
    }
    
    var deleteAccountButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                Text("Delete account")
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                Spacer()
            }
            .padding(.vertical, Spacing.lg)
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
        .buttonStyle(.plain)
    }
    
    var footerText: some View {
        Text("Movo · v\(AppInfo.version)")
            .font(Typography.captionSmall.font)
            .foregroundStyle(Color.movo.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.xs)
    }
    
    // MARK: Skeleton
    
    var profileSkeleton: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.lg) {
                    Circle()
                        .fill(Color.movo.elevated)
                        .frame(width: 82, height: 82)
                        .shimmer()
                    VStack(spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.movo.elevated)
                            .frame(width: 140, height: 16)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.movo.elevated)
                            .frame(width: 180, height: 12)
                            .shimmer()
                    }
                }
                .padding(.top, Spacing.lg)
                
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { i in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.movo.elevated)
                                    .frame(width: 80, height: 12)
                                    .shimmer()
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.movo.elevated)
                                    .frame(width: 120, height: 12)
                                    .shimmer()
                            }
                            .padding(.vertical, Spacing.rowPaddingVertical)
                            .padding(.horizontal, Spacing.lg)
                            if i == 0 {
                                Divider()
                                    .background(Color.movo.border)
                                    .padding(.horizontal, Spacing.lg)
                            }
                        }
                    }
                    .background(Color.movo.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .scrollContentBackground(.hidden)
        .allowsHitTesting(false)
    }
    
    // MARK: Empty State
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.movo.textTertiary)
            Text("Profile unavailable")
                .font(Typography.cardHero.font)
                .foregroundStyle(Color.movo.textPrimary)
            Button("Retry") {
                Task { await userVM.fetchProfile() }
            }
            .buttonStyle(MovoCompactButtonStyle())
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
