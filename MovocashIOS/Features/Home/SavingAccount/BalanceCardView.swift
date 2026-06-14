//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import SwiftUI

struct BalanceCardView: View {

    let account: SavingsAccountInfo
    var showViewCard: Bool
    var onCardTap: () -> Void
    var onViewCardTap: () -> Void

    var body: some View {
        // ── Content drives tile height. No fixed frame. ────────────────────
        VStack(alignment: .leading, spacing: 0) {

            // Top row: eyebrow + type badge
            HStack(alignment: .center) {
                Text("AVAILABLE BALANCE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color.movo.textTertiary)
                Spacer()
                MovoTypeBadge(account.isPrimary ? "PRIMARY" : "ACCOUNT")
            }

            Spacer().frame(height: Spacing.sm)

            // Balance — split cents (mirrors CardItemView.styledBalance)
            styledBalance

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
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(Color.movo.textTertiary)
                    Button(action: onCardTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.movo.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if showViewCard {
                    MovoActionButton("View Card") { onViewCardTap() }
                }
            }
        }
        .padding(Spacing.lg)
        // ── Decoration is a background — never affects geometry ────────────
        .background(
            ZStack {
                // 1. Surface gradient
                LinearGradient(
                    stops: [
                        .init(color: DesignTokens.Palette.cardVoidTop.color,    location: 0.00),
                        .init(color: DesignTokens.Palette.cardVoidMid.color,    location: 0.55),
                        .init(color: DesignTokens.Palette.cardVoidBottom.color, location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint:   .bottomTrailing
                )

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

    // MARK: - Styled balance

    /// Splits "$9,284.21" → "$9,284." full-weight + "21" smaller + dimmed.
    /// Mirrors styledBalance on CardItemView.
    @ViewBuilder
    private var styledBalance: some View {
        let formatted = account.availableBalance.toCurrencyString()
        if let dotIdx = formatted.lastIndex(of: ".") {
            let dollars = "$" + String(formatted[formatted.startIndex...dotIdx])
            let cents   = String(formatted[formatted.index(after: dotIdx)...])
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(dollars)
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .tracking(-1.0)
                    .foregroundColor(Color.movo.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(cents)
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary.opacity(0.45))
            }
        } else {
            Text("$" + formatted)
                .font(.system(size: 40, weight: .bold).monospacedDigit())
                .tracking(-1.0)
                .foregroundColor(Color.movo.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}
