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

