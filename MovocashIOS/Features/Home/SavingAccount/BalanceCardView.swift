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
    var isVCardActive: Bool
    var vCardLastFour: String?
    var onCardTap: () -> Void
    var onViewCardTap: () -> Void
    var onActivateTap: () -> Void
    var onIssuePhysicalCardTap: () -> Void

    var body: some View {
        // ── Content drives tile height. No fixed frame. ────────────────────
        VStack(alignment: .leading, spacing: 0) {

            // Top row: alternate account number label + masked v-card number.
            // Both share the same font/tracking/color — same visual format.
            HStack(alignment: .center) {
                Text("Main MOVO Card")
                    .textStyle(Typography.cardHero)
                    .foregroundColor(Color.movo.textTertiary)
                Spacer()
                if let vCardLastFour {
                    maskedLastFourText(vCardLastFour)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }

            Spacer().frame(height: Spacing.xxs)

            // Balance
            if let bal = account.availableBalance {
                BalanceText(amount: bal, dollarSize: 58, centsSize: 40, centsOpacity: 1.0)
            } else {
                Text("$ —")
                    .font(.system(size: 58, weight: .bold).monospacedDigit())
                    .foregroundColor(Color.movo.textTertiary)
            }

            Spacer().frame(height: Spacing.xxs)

            // Status
            if account.status == .active {
                MovoStatusLabel(.active)
            } else {
                StatusPill(account.status.rawValue, variant: .neutral)
            }

            // Fixed gap — keeps bottom row off the status without an expanding Spacer
            Spacer().frame(height: Spacing.md)

            // ── Bottom metadata row ────────────────────────────────────────
            HStack(alignment: .center) {
                MovoActionButton("ISSUE PHYSICAL CARD".uppercased()) { onIssuePhysicalCardTap() }
                Spacer()
                if isVCardActive {
                    MovoActionButton("View Card".uppercased()) { onViewCardTap() }
                } else {
                    MovoActionButton("Activate Card".uppercased()) { onActivateTap() }
                }
            }
        }
        .padding(Spacing.sm)
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
