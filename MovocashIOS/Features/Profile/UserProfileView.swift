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
    
    var body: some View {
        
        Group {
            if userVM.state == .loading {
                SpinnerView()
            } else if let profile = userVM.profile {
                profileList(profile)
            } else {
                emptyState
            }
        }
        .onAppear {
            if userVM.profile == nil {
                Task { await userVM.fetchProfile() }
            }
        }
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
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Sections  (profile passed in, no more dangling reference)
    
    private func avatarSection(_ profile: UserProfileResponse) -> some View {
        Section {
            VStack(spacing: 10) {
                ProfileImageView(imageURL: profile.profilePicture,
                                 userName: profile.fullName,
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
