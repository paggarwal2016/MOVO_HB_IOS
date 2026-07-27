//
//  VirtualCardPinChoiceView.swift
//  MovocashIOS
//
//  "Set a PIN for your virtual card" choice screen (product mockup, screen 1).
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
                .padding(.top, Spacing.md)

            Spacer(minLength: Spacing.xl)

            glyph

            VStack(spacing: Spacing.sm) {
                Text("Set a PIN for your virtual card")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use the same PIN as your first MOVO card, or create a new one.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)

            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.md) {
                Button(action: onUseExisting) {
                    Text("Use existing PIN")
                        .tracking(1.5)
                }
                .buttonStyle(MovoPrimaryButtonStyle())

                Button(action: onCreateNew) {
                    Text("Create new PIN")
                        .tracking(1.5)
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .padding(.top, Spacing.md)
        .background(Color.movo.surface.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var header: some View {
        ZStack {
            Spacer()
            Text("Virtual card")
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Color.movo.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    private var glyph: some View {
        ZStack {
            Circle()
                .fill(Color.movo.accentTint)
                .frame(width: 128, height: 128)
            Image(systemName: "creditcard.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.movo.accent)
        }
        .padding(.bottom, Spacing.lg)
    }
}
