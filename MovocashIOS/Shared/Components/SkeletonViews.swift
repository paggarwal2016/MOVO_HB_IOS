//
//  SkeletonViews.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/03/26.
//

import SwiftUI

// MARK: - SkeletonBlock (internal building block)

private struct SkeletonBlock: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 7

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - TransactionRowSkeleton
// Matches TransactionRow layout in SavingAccountDetailView

struct TransactionRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 14, cornerRadius: 6)
                    .frame(width: 140)
                SkeletonBlock(height: 11, cornerRadius: 5)
                    .frame(width: 90)
            }

            Spacer()

            SkeletonBlock(height: 14, cornerRadius: 6)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - AccountCardSkeleton
// Matches the 180pt gradient card in SavingAccountDetailView

struct AccountCardSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 180)
            .shimmer()
            .padding(.horizontal, 10)
    }
}

// MARK: - ProfileRowSkeleton
// Matches ProfileRow layout in UserProfileView

struct ProfileRowSkeleton: View {
    var leadingWidth: CGFloat = 80
    var trailingWidth: CGFloat = 120

    var body: some View {
        HStack {
            SkeletonBlock(height: 14, cornerRadius: 6)
                .frame(width: leadingWidth)
            Spacer()
            SkeletonBlock(height: 14, cornerRadius: 6)
                .frame(width: trailingWidth)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ProfileAvatarSkeleton
// Matches avatarSection layout in UserProfileView

struct ProfileAvatarSkeleton: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 65, height: 65)
                .shimmer()
            SkeletonBlock(height: 16, cornerRadius: 7)
                .frame(width: 140)
            SkeletonBlock(height: 13, cornerRadius: 6)
                .frame(width: 100)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - LinkedAccountSkeleton
// Matches ActionCard / LinkedAccountsSectionView empty-state shape

struct LinkedAccountSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(height: 16, cornerRadius: 6)
                .frame(width: 120)
            SkeletonBlock(height: 13, cornerRadius: 5)
            SkeletonBlock(height: 13, cornerRadius: 5)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 40)
            SkeletonBlock(height: 44, cornerRadius: 10)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 15)
    }
}

// MARK: - DashboardSkeletonView
// Full-page skeleton mirroring all dashboard sections during initial load

struct DashboardSkeletonView: View {
    var body: some View {
        VStack(spacing: 20) {
            // primaryAccount — balance card
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 180)
                .shimmer()
                .padding(.horizontal, 15)

            // quick action buttons 2×1 grid
            HStack(spacing: 12) {
                SkeletonBlock(height: 52, cornerRadius: 14)
                SkeletonBlock(height: 52, cornerRadius: 14)
            }
            .padding(.horizontal, 15)

            // payAnyone action card
            SkeletonBlock(height: 110, cornerRadius: 16)
                .padding(.horizontal, 15)

            // linkedAccounts card
            SkeletonBlock(height: 110, cornerRadius: 16)
                .padding(.horizontal, 15)

            // myCards section
            CardSkeletonView()
                .padding(.horizontal, 15)
        }
        .padding(.top, 16)
    }
}

// MARK: - AccountRowSkeleton
// Matches AccountRowView layout in AccountListSheetView

struct AccountRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 14, cornerRadius: 6)
                    .frame(width: 100)
                SkeletonBlock(height: 12, cornerRadius: 5)
                    .frame(width: 140)
            }

            Spacer()

            SkeletonBlock(height: 14, cornerRadius: 6)
                .frame(width: 60)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
