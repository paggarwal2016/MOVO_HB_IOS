//
//  VirtualCardPinChoiceView.swift
//  MovocashIOS
//
//  "Set a PIN for your Cash Card" choice screen.
//  The user either reuses the PIN from their first MOVO card or creates a new
//  one. This view only presents the choice — the caller decides what each action
//  navigates to.
//

import SwiftUI

struct VirtualCardPinChoiceView: View {

    /// Reuse the PIN already set on the first MOVO card.
    let onUseExisting: () -> Void
    /// Create a brand-new PIN for this virtual card.
    let onCreateNew: () -> Void
    /// Dismiss the flow.
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)

            glyph

            VStack(spacing: Spacing.sm) {
                Text("Set a PIN for your digital cash card")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Reuse the PIN from your existing card, or create a new one.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xxl)

            Spacer(minLength: Spacing.xxl)

            VStack(spacing: Spacing.md) {
                optionRow(
                    systemImage: "square.on.square",
                    iconTint: Color.movo.accent,
                    iconBackground: Color.movo.accentTint,
                    title: "Use my existing PIN",
                    subtitle: "Same PIN as your first card",
                    isHighlighted: true,
                    action: onUseExisting
                )

                optionRow(
                    systemImage: "plus",
                    iconTint: Color.movo.textTertiary,
                    iconBackground: Color.movo.elevated,
                    title: "Create a new PIN",
                    subtitle: "Set a fresh 4-digit code",
                    isHighlighted: false,
                    action: onCreateNew
                )
            }
            .padding(.horizontal, Spacing.xl)

            Spacer(minLength: Spacing.xl)

            securityFooter
                .padding(.bottom, Spacing.xxl)
        }
        .background(Color.movo.surface.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        Text("Digital Cash Card")
            .textStyle(Typography.cardTitle)
            .foregroundStyle(Color.movo.textPrimary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Glyph

    private var glyph: some View {
        ZStack {
            Circle()
                .fill(Color.movo.accentTint)
                .frame(width: 80, height: 80)
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.movo.accent)
        }
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Option Row

    private func optionRow(
        systemImage: String,
        iconTint: Color,
        iconBackground: Color,
        title: String,
        subtitle: String,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(iconTint)
                }

                // Title + subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .textStyle(Typography.body)
                        .foregroundStyle(Color.movo.textPrimary)
                    Text(subtitle)
                        .textStyle(Typography.caption)
                        .foregroundStyle(Color.movo.textTertiary)
                }

                Spacer(minLength: 0)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.movo.textTertiary)
            }
            .padding(Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                    .fill(Color.movo.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Color.movo.accent.opacity(0.45) : Color.movo.borderStrong.opacity(0.20),
                        lineWidth: isHighlighted ? Stroke.thin : Stroke.hairline
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Security Footer

    private var securityFooter: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.movo.textTertiary)
            Text("Your PIN is encrypted and never shared.")
                .textStyle(Typography.caption)
                .foregroundStyle(Color.movo.textTertiary)
        }
        .padding(.horizontal, Spacing.xl)
    }
}
