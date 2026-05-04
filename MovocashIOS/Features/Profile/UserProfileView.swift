//
//  UserProfileView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 18/03/26.
//

import Foundation
import SwiftUI

struct UserProfileView: View {
    
    @EnvironmentObject var userVM: UserViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var lockManager: AppLockManager
    
    @ObservedObject var dashboardVM: DashboardViewModel
    
    @ObservedObject var achVM: ACHViewModel
    @StateObject private var plaidVM: PlaidAchViewModel

    @State private var showDisableBiometricAlert = false
    @State private var showBiometricEnrollSheet  = false
    @State private var showSecuritySettings      = false

    init(container: AppContainer, dashboardVM: DashboardViewModel, achVM: ACHViewModel) {
        self.dashboardVM = dashboardVM
        self.achVM = achVM
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }
    
    private var effectiveBiometricType: BiometricType {
        lockManager.isBiometricAvailable
            ? lockManager.biometricType
            : lockManager.hardwareBiometricType
    }

    private var biometricToggleBinding: Binding<Bool> {
        Binding<Bool>(
            get: { lockManager.isBiometricEnabled },
            set: { isOn in
                if isOn {
                    guard lockManager.isPasscodeSet else {
                        lockManager.showTemporaryError("Set a passcode first to enable biometrics.")
                        return
                    }
                    showBiometricEnrollSheet = true
                } else {
                    showDisableBiometricAlert = true
                }
            }
        )
    }

    // Prefers the fully-fetched profile; falls back to dashboard data while the
    // separate profile fetch is in-flight so the tab shows content immediately.
    private var effectiveProfile: UserProfileResponse? {
        userVM.profile ?? dashboardVM.userDetails.map { UserProfileResponse(from: $0) }
    }
    
    // Prefers live ACH accounts after fetch; falls back to dashboard linked accounts
    // on first load so the section populates without waiting for the separate fetch.
    private var effectiveAccounts: [ACHAccount] {
        if !achVM.accounts.isEmpty { return achVM.accounts }
        return dashboardVM.linkedAccounts?.linkedAccounts?.map { ACHAccount(from: $0) } ?? []
    }
    
    var body: some View {
        Group {
            if let profile = effectiveProfile {
                profileList(profile)
            } else if userVM.state == .loading {
                profileSkeleton
            } else {
                emptyState
            }
        }
        .task {
            guard achVM.accounts.isEmpty else { return }
            await achVM.fetchAccounts()
        }
    }
    
    // MARK: - Profile Skeleton
    
    private var profileSkeleton: some View {
        List {
            Section {
                ProfileAvatarSkeleton()
            }
            Section("Personal info") {
                ForEach(0..<4, id: \.self) { _ in ProfileRowSkeleton() }
            }
            Section("Contact") {
                ForEach(0..<2, id: \.self) { _ in ProfileRowSkeleton(leadingWidth: 50, trailingWidth: 150) }
            }
            Section("Address") {
                ForEach(0..<4, id: \.self) { _ in ProfileRowSkeleton(leadingWidth: 60, trailingWidth: 130) }
            }
        }
        .listStyle(.insetGrouped)
        .allowsHitTesting(false)
    }
    
    // MARK: - Empty / Error State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Profile unavailable")
                .font(.headline)
            Button("Retry") {
                Task { await userVM.fetchProfile() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Profile List
    
    private func profileList(_ profile: UserProfileResponse) -> some View {
        List {
            avatarSection(profile)
            securitySection
            accountStatusSection(profile)
            linkedBankAccountsSection
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await userVM.refresh()
            await achVM.fetchAccounts()
        }
        .sheet(isPresented: $showBiometricEnrollSheet) {
            BiometricEnrollView(
                lockManager: lockManager,
                onEnable: { showBiometricEnrollSheet = false },
                onSkip:   { showBiometricEnrollSheet = false }
            )
        }
        .alert("Disable \(effectiveBiometricType.displayName)?", isPresented: $showDisableBiometricAlert) {
            Button("Disable", role: .destructive) { lockManager.revokeBiometricSafely() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll need your passcode to unlock MovoCash.")
        }
        .navigationDestination(isPresented: $showSecuritySettings) {
            SecuritySettingsView(lockManager: lockManager)
        }
    }
    
    // MARK: - Linked Bank Accounts
    
    private var linkedBankAccountsSection: some View {
        Section("Linked bank accounts") {
            if achVM.state == .loading && effectiveAccounts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if effectiveAccounts.isEmpty {
                Text("No linked accounts")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(effectiveAccounts, id: \.achAccountId) { account in
                    HStack(spacing: 12) {
                        ZStack {
                            let initial = account.institutionName.first.map(String.init) ?? "?"
                            RoundedRectangle(cornerRadius: 10)
                                .fill(account.logoImage != nil ? Color(.systemBackground) : Color.matteBlack)
                                .frame(width: 46, height: 46)
                            if let logo = account.logoImage {
                                Image(uiImage: logo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 45, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Text(initial.uppercased())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray5), lineWidth: account.logoImage != nil ? 1 : 0)
                        )
                                                
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.accountName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(account.institutionName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(account.accountNumber)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            guard !account.isDefault else { return }
                            Task { await achVM.updateAccount(id: account.achAccountId)
                                   await achVM.fetchAccounts()
                            }
                        } label: {
                            Image(systemName: account.isDefault ? "star.fill" : "star")
                                .font(.system(size: 15))
                                .foregroundStyle(account.isDefault ? Color.yellow : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        Button {
                            AlertManager.shared.showConfirmation(
                                title: "Remove Account",
                                message: "Are you sure you want to remove \(account.institutionName) - \(account.accountName)?",
                                onConfirm: {
                                    Task { await achVM.deleteAccount(id: account.achAccountId) }
                                }
                            )
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Button {
                Task {
                    await plaidVM.startPlaidLink()
                    if plaidVM.linkedAccount != nil {
                        await achVM.fetchAccounts()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.softBlue)
                    Text(plaidVM.state == .loading ? "Connecting..." : "Connect Bank Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.softBlue)
                }
            }
            .disabled(plaidVM.state == .loading)
        }
    }
    
    // MARK: - Sections  (profile passed in, no more dangling reference)

    private var securitySection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lockManager.isBiometricHardwarePresent
                              ? (lockManager.isBiometricEnabled ? Color.green : Color(.systemGray3))
                              : Color.blue)
                        .frame(width: 32, height: 32)
                    Image(systemName: lockManager.isBiometricHardwarePresent
                          ? effectiveBiometricType.systemImageName
                          : "lock.shield.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(lockManager.isBiometricHardwarePresent
                         ? effectiveBiometricType.displayName
                         : "Security Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(lockManager.isBiometricHardwarePresent
                         ? (lockManager.isBiometricEnabled ? "Enabled" : "Disabled")
                         : "Passcode & authentication")
                        .font(.caption)
                        .foregroundStyle(
                            lockManager.isBiometricHardwarePresent && lockManager.isBiometricEnabled
                                ? Color.green : Color.secondary
                        )
                }

                Spacer()

                if lockManager.isBiometricHardwarePresent {
                    Toggle("", isOn: biometricToggleBinding)
                        .labelsHidden()
                        .tint(.green)
                        .fixedSize()
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 0.5, height: 22)
                        .padding(.horizontal, 4)
                }

                Button { showSecuritySettings = true } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        } header: {
            Text("Authentication & Security")
        } footer: {
            if lockManager.isBiometricHardwarePresent {
                Text(lockManager.isBiometricEnabled
                     ? "\(effectiveBiometricType.displayName) is active for quick, secure sign-in."
                     : "Enable \(effectiveBiometricType.displayName) for faster, more secure access.")
            }
        }
    }

    private func avatarSection(_ profile: UserProfileResponse) -> some View {
        Section {
            VStack(spacing: 20) {
                ProfileImageView(
                    imageURL: profile.profilePicture,
                    userName: profile.initials,
                    width: 82,
                    height: 82
                )
                .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 2))

                VStack(spacing: 4) {
                    Text(profile.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text("@\(profile.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                    Text(profile.displayEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    PrimaryButton(
                        image: Image(systemName: "person.fill"),
                        title: "View Profile"
                    ) { }

                    PrimaryButton(
                        image: Image(systemName: "trash.fill"),
                        title: "Delete Account",
                        backgroundColor: Color.primary,
                        textColor: Color.red
                    ) {
                        AlertManager.shared.showConfirmation(
                            title: "Delete",
                            message: "Are you sure you want to permanently delete your account?",
                            onConfirm: {
                                Task {
                                    let success = await userVM.deleteAccount()
                                    if success {
                                        lockManager.logout()
                                        await sessionManager.logout(appState: appState)
                                        ToastManager.shared.show("Account delete successfully.", style: .success, position: .bottom)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color(.secondarySystemGroupedBackground))
            .listRowSeparator(.hidden)
        }
    }

    private func accountStatusSection(_ profile: UserProfileResponse) -> some View {
        Section("Account Status") {
            accountStatusRow(
                icon: "person.badge.shield.checkmark.fill",
                iconColor: profile.isAdditionalKycRequired ? .orange : .green,
                label: "KYC Status",
                style: profile.isAdditionalKycRequired ? .required : .complete
            )
            accountStatusRow(
                icon: "checkmark.seal.fill",
                iconColor: profile.cipAllowed ? .green : .red,
                label: "CIP Status",
                style: profile.cipAllowed ? .allowed : .notAllowed
            )
            accountStatusRow(
                icon: "link.circle.fill",
                iconColor: profile.isPlaidAuthRequired ? .orange : .green,
                label: "Bank Link",
                style: profile.isPlaidAuthRequired ? .required : .connected
            )
            accountStatusRow(
                icon: "checkmark.circle.fill",
                iconColor: !profile.isDeactivated ? .green : .red,
                label: "Account",
                style: !profile.isDeactivated ? .active : .deactivated
            )
        }
    }

    private func accountStatusRow(icon: String, iconColor: Color, label: String, style: StatusStyle) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: style.icon).font(.caption2)
                Text(style.label).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(style.color.opacity(0.12))
            .foregroundStyle(style.color)
            .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Reusable Components

struct ProfileRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .blue

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
