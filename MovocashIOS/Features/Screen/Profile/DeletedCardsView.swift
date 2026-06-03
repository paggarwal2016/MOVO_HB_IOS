//
//  DeletedCardsView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 03/06/26.
//

import SwiftUI

/// Read-only list of the user's deleted (disabled) cards.
///
/// The list is sourced from `DashboardViewModel.deletedCards`, which holds the
/// `enabled == false` entries from the decrypted MYCARDS payload. Presented from
/// Profile → Linked Bank Accounts → Deleted cards.
struct DeletedCardsView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss

    let cards: [VCardListResponse]

    var body: some View {
        ZStack {
            MovoBackground()

            VStack(spacing: 0) {
                navBar

                if cards.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.sm) {
                            ForEach(cards, id: \.id) { card in
                                cardRow(card)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xxxl)
                    }
                }
            }

            StatusBarScrim()
        }
        .background(Color.movo.background.ignoresSafeArea())
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Deleted Cards")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Card Row

    private func cardRow(_ card: VCardListResponse) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.movo.elevated)
                    .frame(width: 44, height: 44)
                Image(systemName: "creditcard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.movo.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(card.savingsAccountNickname ?? card.displayName)
                    .font(Typography.body.font)
                    .foregroundStyle(Color.movo.textPrimary)
                Text(card.maskedNumber)
                    .font(Typography.subtitle.font)
                    .foregroundStyle(Color.movo.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.rowPaddingVertical)
        .padding(.horizontal, Spacing.lg)
        .background(Color.movo.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.movo.textSecondary)
            Text("No deleted cards")
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
