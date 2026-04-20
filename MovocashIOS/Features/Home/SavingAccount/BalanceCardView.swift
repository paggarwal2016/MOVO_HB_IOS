//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import SwiftUI

struct BalanceCardView: View {

    let account: SavingsAccountDetailsResponse
    var backgroundColor: Color = Color(#colorLiteral(red: 0.8984523416, green: 0.8984523416, blue: 0.8984523416, alpha: 1))
    var onCardTap: () -> Void
    var onPrimaryTap: () -> Void
    var onViewCardTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top section ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {

                // Title + pencil
                HStack(spacing: 8) {
                    Text(account.nickname ?? "Primary Account")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))

                    Button { onPrimaryTap() } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(7)
                            .background(Color(#colorLiteral(red: 0.8661081791, green: 0.8661081791, blue: 0.8661081791, alpha: 1)))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Active status — plain green, no background
                if account.status.rawValue == "Active" {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    }
                }

                // Balance
                Text(account.formattedBalance)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)

            Divider()

            // ── Bottom row ────────────────────────────────────────────────
            Button { onViewCardTap() } label: {
                HStack {
                    Text("View cards")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
                .onTapGesture { onCardTap() }
        )
        .padding(.horizontal, 15)
    }
}
