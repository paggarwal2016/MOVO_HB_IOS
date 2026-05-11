//
//  ActionCard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    var isLoading: Bool = false
    var onButtonTap: () -> Void = {}

    private let theme = MovoTheme.color

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            PayAnyoneIllustration()
                .frame(width: 80, height: 80)
                .frame(maxWidth: .none, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .textStyle(Typography.cardHero)
                    .foregroundStyle(theme.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .textStyle(Typography.subtitle)
                    .foregroundStyle(theme.textSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onButtonTap) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: theme.background.color))
                                .scaleEffect(0.8)
                        } else {
                            Text(buttonLabel)
                                .textStyle(Typography.button)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(theme.background.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevated.color)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderStrong.color, lineWidth: DesignTokens.Stroke.hairline)
        )
        .padding(.horizontal, 15)
    }
}

// MARK: - Illustration

private struct PayAnyoneIllustration: View {
    private let theme = MovoTheme.color

    var body: some View {
        ZStack {
            // Sender — back-left person
            Image(systemName: "person")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(theme.textTertiary.color)
                .offset(x: -16, y: 8)

            // Money note flying between the two
            Image(systemName: "banknote")
                .font(.system(size: 18, weight: .thin))
                .foregroundStyle(theme.accent.color)
                .rotationEffect(.degrees(-25))
                .offset(x: 2, y: -16)

            // Recipient — front-right person
            Image(systemName: "person")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(theme.textSecondary.color)
                .offset(x: 18, y: 2)
        }
    }
}
