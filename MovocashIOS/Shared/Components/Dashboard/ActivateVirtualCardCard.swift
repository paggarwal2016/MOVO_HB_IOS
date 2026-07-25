//
//  ActivateVirtualCardCard.swift
//  MovocashIOS
//
//  Dashboard call-to-action card for activating a virtual card. Visual style
//  mirrors `ActionCard` (eyebrow title + cardVoid surface + silver hairline).
//

import SwiftUI

struct ActivateVirtualCardCard: View {
    var title: String = "Activate virtual card"
    var description: String = "Activate your virtual card to start spending."
    var buttonLabel: String = "Activate card"
    var isLoading: Bool = false
    var onButtonTap: () -> Void = {}

    private let theme = MovoTheme.color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section eyebrow.
            Text(title.uppercased())
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            Button(action: onButtonTap) {
                VStack(spacing: Spacing.sm) {
                    // Circular tinted badge holding the card glyph.
                    ZStack {
                        Circle()
                            .fill(Color.movo.accentTint)
                        Image(systemName: "creditcard")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color.movo.accent)
                    }
                    .frame(width: 40, height: 40)
                    .padding(.top, Spacing.md)

                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 16, weight: .regular))
                            .tracking(0)
                            .foregroundStyle(theme.textSecondary.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Accent action — shows a spinner while the activation is in flight.
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text(buttonLabel)
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(0.2)
                                .foregroundStyle(Color.movo.accent)
                        }
                    }
                    .padding(.bottom, Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.lg)
                .background(LinearGradient.cardVoid)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                        .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
