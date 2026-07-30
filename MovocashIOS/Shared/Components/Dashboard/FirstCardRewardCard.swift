//
//  FirstCardRewardCard.swift
//  MovocashIOS
//

import SwiftUI

struct FirstCardRewardCard: View {

    var onActivate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            MovoMVSymbol()
                .frame(width: 25, height: 25)

            rewardPill

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Your first digital cash card is on us.")
                    .textStyle(Typography.cardHero)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Free card \u{2014} add to Apple Pay in one tap.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onActivate) {
                Text("Activate my card")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(LinearGradient.cardVoid)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    // MARK: - Reward Pill

    private var rewardPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("REWARD UNLOCKED")
                .textStyle(Typography.eyebrow)
        }
        .foregroundColor(Color.movo.accent)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(Color.movo.accentTint)
                .overlay(
                    Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                )
        )
    }
}
