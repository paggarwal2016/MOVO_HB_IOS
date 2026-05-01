//
//  LinkedAccountsSectionView.swift
//  MovocashIOS
//

import SwiftUI

struct LinkedAccountsSectionView: View {

    let title: String
    let description: String
    let buttonLabel: String
    let accounts: [ACHAccount]
    let isLoading: Bool
    var isLoadingAccounts: Bool = false
    var onLinkAccount: () -> Void
    var onConnectAnother: () -> Void

    var body: some View {
        if isLoadingAccounts && accounts.isEmpty {
            LinkedAccountSkeleton()
        } else if accounts.isEmpty {
            emptyState
        } else {
            listState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            PrimaryButton(
                title: buttonLabel,
                backgroundColor: .gray.opacity(0.1),
                textColor: .black,
                isLoading: isLoading,
                action: onLinkAccount
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 15)
    }

    // MARK: - List State

    private var listState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(accounts.indices, id: \.self) { index in
                    LinkedAccountRowView(account: accounts[index])
                    if index < accounts.count - 1 {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(action: onConnectAnother) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Connect another bank")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color(.systemGray3))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 15)
    }
}

// MARK: - Row

struct LinkedAccountRowView: View {

    let account: ACHAccount

    private var maskedNumber: String {
        let last4 = String(account.accountNumber.suffix(4))
        return "•••• \(last4)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 3) {
                Text("\(account.institutionName) \(account.accountName)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(maskedNumber)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(account.formattedBalance)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var avatarView: some View {
        let initial = account.institutionName.first.map(String.init) ?? "?"
        ZStack {
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
    }
}
