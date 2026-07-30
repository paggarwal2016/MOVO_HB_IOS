//
//  CreateCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/04/26.
//

import SwiftUI

struct CreateCardView: View {

    var title: String   = "Get your\ncash card"
    var message: String = "Spend instantly\nApple Pay ready"
    var caption: String? = nil
    var buttonLabel: String = "Create card"
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // Match PrimaryAccountContent / BalanceCardView surface — the cardVoid gradient.
            LinearGradient.cardVoid

            Image("CardFrontHerring")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 162)
                .rotationEffect(.degrees(3), anchor: .center)
                .offset(x: 20, y: 14)
                // Heritage Green ambient glow — card seal reads against near-black bg
                .shadow(color: DesignTokens.Palette.accent.color.opacity(0.28),
                        radius: 22, x: -10, y: 0)
                // Depth shadow — card lifts off the panel surface
                .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.sm) {

                    // 1 — Eyebrow: title param = "REWARD UNLOCKED" from API
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(Typography.pill.font)
                            .foregroundStyle(DesignTokens.Palette.accentEyebrow.color)
                        Text(title)
                            .textStyle(Typography.pill)
                            .foregroundStyle(DesignTokens.Palette.accentEyebrow.color)
                    }

                    // 2 — Hero title: message param = main heading from API
                    Text(message)
                        .textStyle(Typography.cardHero)
                        .foregroundStyle(Color.movo.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // 3 — Subtitle: caption param = supporting line from API
                    if let caption, !caption.isEmpty {
                        Text(caption)
                            .textStyle(Typography.subtitle)
                            .foregroundStyle(Color.movo.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onTap) {
                        Text(buttonLabel)
                            .textStyle(Typography.button)
                            .textCase(.uppercase)
                            .foregroundColor(Color.movo.onAccent)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.button)
                                    .fill(Color.movo.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                Spacer(minLength: 128)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

// MARK: - Card Mock Illustration

private struct CardMockIllustration: View {

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(Color.movo.elevatedHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: DesignTokens.Stroke.hairline)
                )

            VStack(alignment: .leading, spacing: 0) {

                // Branding row
                HStack(spacing: 5) {
                    
                    Image("herringLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    
                    Text("MOVOCASH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.movo.textPrimary)
                        .kerning(1.2)
                }

                Spacer().frame(height: 10)

                // Balance
                Text("BALANCE")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(Color.movo.textTertiary)
                    .kerning(0.8)

                Spacer().frame(height: 3)

                Text("$0.00")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.movo.textPrimary)

                Spacer()

                // Chip + contactless icons
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.movo.textTertiary.opacity(0.5))
                        .frame(width: 22, height: 16)

                    Image(systemName: "wave.3.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.movo.textTertiary.opacity(0.6))
                }

                Spacer().frame(height: 8)

                // Masked card number dots
                HStack(spacing: 6) {
                    dotGroup(count: 4)
                    dotGroup(count: 4)
                    dotGroup(count: 4)
                }
            }
            .padding(14)
        }
    }

    private func dotGroup(count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(Color.movo.textTertiary.opacity(0.5))
                    .frame(width: 3.5, height: 3.5)
            }
        }
    }
}
