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

    init(container: AppContainer, dashboardVM: DashboardViewModel, achVM: ACHViewModel) {
        self.dashboardVM = dashboardVM
        self.achVM = achVM
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
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
            personalInfoSection(profile)
            contactSection(profile)
            addressSection(profile)
            idVerificationSection(profile)
            accountStatusSection(profile)
            linkedBankAccountsSection
            
            //            PrimaryButton(title: "Delete Account") {
            //                AlertManager.shared.showConfirmation(
            //                    title: "Delete",
            //                    message: "Are you sure you want to permanently delete your account?",
            //                    onConfirm: {
            //                        Task {
            //                            let success = await userVM.deleteAccount()
            //                            if success {
            //                                lockManager.logout()
            //                                await sessionManager.logout(appState: appState)
            //                                ToastManager.shared.show("Account delete successfully.", style: .success, position: .bottom)
            //                            }
            //                        }
            //                    }
            //                )
            //            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await userVM.refresh()
            await achVM.fetchAccounts()
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
    
    private func avatarSection(_ profile: UserProfileResponse) -> some View {
        Section {
            VStack(spacing: 10) {
                ProfileImageView(imageURL: profile.profilePicture,
                                 userName: profile.initials,
                                 width: 65,
                                 height: 65)
                Text(profile.fullName)
                    .font(.title2).fontWeight(.semibold)
                Text("@\(profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    StatusBadge(status: profile.emailVerified ? .emailVerified : .emailUnverified)
                    StatusBadge(status: profile.smsVerified ? .smsVerified : .smsUnverified)
                    StatusBadge(status: profile.isTwoFactorEnabled ? .twoFactorEnabled : .twoFactorDisabled)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
    
    private func personalInfoSection(_ profile: UserProfileResponse) -> some View {
        Section("Personal info") {
            ProfileRow(label: "First name",   value: profile.firstName ?? "--")
            ProfileRow(label: "Last name",    value: profile.lastName ?? "--")
            ProfileRow(label: "Date of birth",value: profile.dob ?? "--")
            ProfileRow(label: "Customer ID",  value: "\(profile.customerId)")
        }
    }
    
    private func contactSection(_ profile: UserProfileResponse) -> some View {
        Section("Contact") {
            ProfileRow(label: "Email", value: profile.displayEmail)
            ProfileRow(label: "Phone", value: profile.displayPhone)
        }
    }
    
    private func addressSection(_ profile: UserProfileResponse) -> some View {
        Section("Address") {
            ProfileRow(label: "Line 1", value: profile.addressLine1 ?? "--")
            if let line2 = profile.addressLine2, !line2.isEmpty {
                ProfileRow(label: "Line 2", value: line2)
            }
            ProfileRow(label: "City / State", value: {
                let parts = [profile.city, profile.state].compactMap { $0?.isEmpty == false ? $0 : nil }
                return parts.isEmpty ? "--" : parts.joined(separator: ", ")
            }())
            ProfileRow(label: "ZIP",          value: profile.zip ?? "--")
        }
    }
    
    private func idVerificationSection(_ profile: UserProfileResponse) -> some View {
        Section("ID verification") {
            ProfileRow(label: "License number", value: profile.driversLicenseNumber ?? "--")
            ProfileRow(label: "State",          value: profile.driversLicenseState ?? "--")
            ProfileRow(label: "Expiration",     value: profile.driversLicenseExpiration ?? "--")
        }
    }
    
    private func accountStatusSection(_ profile: UserProfileResponse) -> some View {
        Section("Account status") {
            StatusRow(label: "KYC required", isRequired: profile.isAdditionalKycRequired, trueStyle: .required, falseStyle: .complete)
            StatusRow(label: "CIP status", isRequired: profile.cipAllowed, trueStyle: .allowed, falseStyle: .notAllowed)
            StatusRow(label: "Plaid auth", isRequired: profile.isPlaidAuthRequired, trueStyle: .connected, falseStyle: .required)
            StatusRow(label: "Account active", isRequired: !profile.isDeactivated, trueStyle: .active, falseStyle: .deactivated)
        }
    }
}

// MARK: - Reusable Components

struct ProfileRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
