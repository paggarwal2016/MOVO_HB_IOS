//
//  CreateCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/04/26.
//

import SwiftUI

struct CreateCardView: View {

    var title: String   = "Get your first cash card"
    var message: String = "Spend instantly · Apple Pay ready"
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // MARK: - Left column
            VStack(alignment: .leading, spacing: 10) {

                // Title
                Text(title)
                    .textStyle(Typography.cardHero)
                    .foregroundStyle(Color.movo.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Subtitle
                Text(message)
                    .textStyle(Typography.subtitle)
                    .foregroundStyle(Color.movo.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // CTA button
                Button(action: onTap) {
                    HStack(spacing: 7) {
                        Text("Create card")
                            .textStyle(Typography.button)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.movo.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.movo.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: - Right column: rotated card illustration
            CardMockIllustration()
                .frame(width: 138, height: 95)
                .rotationEffect(.degrees(10), anchor: .center)
                .padding(.top, 6)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.movo.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                .strokeBorder(Color.movo.border, lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

// MARK: - Card Mock Illustration

private struct CardMockIllustration: View {

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(Color.movo.elevatedHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .strokeBorder(Color.movo.borderStrong,
                                      lineWidth: DesignTokens.Stroke.hairline)
                )

            VStack(alignment: .leading, spacing: 0) {

                Text("CASH CARD")
                    .textStyle(Typography.eyebrow)
                    .foregroundStyle(Color.movo.textTertiary)

                Spacer().frame(height: 6)

                Text("Your name here")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.movo.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    dotGroup(count: 4)
                    dotGroup(count: 4)
                }
            }
            .padding(12)
        }
    }

    private func dotGroup(count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(Color.movo.textTertiary.opacity(0.7))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
