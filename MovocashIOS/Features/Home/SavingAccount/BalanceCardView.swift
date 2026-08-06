//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import SwiftUI
import UIKit

struct BalanceCardView: View {

    let account: SavingsAccountInfo
    var showViewCard: Bool
    var onCardTap: () -> Void
    var onViewCardTap: () -> Void

    // Re-renders when Dynamic Type changes so UIFontMetrics.scaledValue
    // returns the current scaled size in body.
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        let _ = sizeCategory
        let scaledFallback = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 58)
        // ── Content drives tile height. No fixed frame. ────────────────────
        VStack(alignment: .leading, spacing: 0) {

            // Top row: eyebrow + type badge
            HStack(alignment: .center) {
                Text("MOVO AVAILABLE BALANCE")
                    .movoFont(.labelCaps)
                    .tracking(1.2)
                    .foregroundColor(Color.movo.textTertiary)
                Spacer()
                MovoTypeBadge(account.isPrimary ? "PRIMARY" : "ACCOUNT")
            }

            Spacer().frame(height: Spacing.sm)

            // Balance
            if let bal = account.availableBalance {
                BalanceText(amount: bal, dollarSize: 58, centsSize: 40, centsOpacity: 1.0)
            } else {
                Text("$ —")
                    .font(.system(size: scaledFallback, weight: .bold).monospacedDigit())
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer().frame(height: Spacing.sm)

            // Status
            if account.status == .active {
                MovoStatusLabel(.active)
            } else {
                StatusPill(account.status.rawValue, variant: .neutral)
            }

            // Fixed gap — keeps bottom row off the status without an expanding Spacer
            Spacer().frame(height: Spacing.xl)

            // ── Bottom metadata row ────────────────────────────────────────
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Text("••\(account.accountNumber.suffix(4))")
                        .font(.system(.title3, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(Color.movo.textTertiary)
                    Button(action: onCardTap) {
                        Image(systemName: "info.circle")
                            .font(.system(.callout, weight: .medium))
                            .foregroundColor(Color.movo.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if showViewCard {
                    MovoActionButton("View Card".uppercased()) { onViewCardTap() }
                }
            }
        }
        .padding(Spacing.lg)
        // ── Decoration is a background — never affects geometry ────────────
        .background(
            ZStack {
                // 1. Surface gradient
                LinearGradient.cardVoid

                // 2. Silver sheen — top-leading sweep
                RadialGradient(
                    colors: [
                        DesignTokens.Palette.silverTint.color.opacity(0.06),
                        .clear
                    ],
                    center:      UnitPoint(x: 0.08, y: 0.08),
                    startRadius: 0,
                    endRadius:   180
                )

                // 3. Hairline top edge — clear → silver 22% → clear
                LinearGradient(
                    colors: [
                        .clear,
                        DesignTokens.Palette.silverTint.color.opacity(0.22),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint:   .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: Stroke.hairline)
        )
        // Whole tile is tappable; Button views inside take priority for their areas
        .contentShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .onTapGesture { onCardTap() }
    }

}
