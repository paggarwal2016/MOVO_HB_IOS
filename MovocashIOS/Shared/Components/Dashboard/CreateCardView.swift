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
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // Match PrimaryAccountContent / BalanceCardView surface — the cardVoid gradient.
            LinearGradient.cardVoid

            Image("CardFrontHerring")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 162)
                .rotationEffect(.degrees(8), anchor: .center)
                .offset(x: 20, y: 16)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.sm) {

                    Text(title)
                        .textStyle(Typography.cardHero)
                        .foregroundStyle(Color.movo.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .textStyle(Typography.subtitle)
                        .foregroundStyle(Color.movo.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onTap) {
                        HStack(spacing: 6) {
                            Text("Create card")
                                .textStyle(Typography.button)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .buttonStyle(SoftAccentButtonStyle())
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
