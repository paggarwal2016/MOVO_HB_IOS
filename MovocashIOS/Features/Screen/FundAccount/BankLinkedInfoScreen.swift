//
//  BankLinkedInfoScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 27/05/26.
//

import SwiftUI

/// Informational sheet shown before bank linking. It does NOT run Plaid itself —
/// tapping "Continue" signals the parent (via `onContinue`) and dismisses, so the
/// parent can present Plaid on a clean stack and own the success screen.
struct BankLinkedInfoScreen: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.securedDismiss) private var securedDismiss
    /// Called when the user taps "Continue". The parent starts the Plaid flow
    /// after this sheet has dismissed (typically from the sheet's `onDismiss`).
    var onContinue: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {

            // Header — co-brand lockup centered; close pinned to the top-right.
            HStack(spacing: Spacing.lg) {

                // MOVO logo + wordmark
                HStack(spacing: Spacing.sm) {
                    MovoMVSymbol()
                        .frame(width: 32, height: 32)
                    Text("MOVO")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(1.5)
                        .foregroundColor(Color.movo.textPrimary)
                }

                // Vertical divider between the two brands
                Rectangle()
                    .fill(Color.movo.borderStrong)
                    .frame(width: Stroke.hairline, height: 26)

                // Plaid logo + wordmark
                HStack(spacing: Spacing.sm) {
                    Image("plaid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("PLAID")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(1.5)
                        .foregroundColor(Color.movo.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.huge)
            .overlay(alignment: .topTrailing) {
                CircularNavButton(systemName: "xmark") { (securedDismiss ?? dismiss)() }
                    .accessibilityLabel("Close")
            }

            // Title
            Text("MOVO partners with Plaid to connect your accounts")
                .textStyle(Typography.sectionTitle)
                .foregroundColor(Color.movo.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Feature rows
            VStack(alignment: .leading, spacing: Spacing.xl) {
                featureRow(
                    icon: "checkmark.shield.fill",
                    title: "Trusted",
                    description: "Plaid connects to 12,000+ banks and 300M+ people across the US."
                )
                featureRow(
                    icon: "lock.fill",
                    title: "Secure",
                    description: "Your data is encrypted with 256-bit security. MOVO can't see your passwords."
                )
            }

            //Spacer().frame(height: Spacing.md)

            // Footer
            disclaimerText()

            // Continue CTA — dismiss this sheet first, then let the parent start
            // Plaid (see PlaidLinkFlowModifier wired on the parent).
            Button("Continue") {
                onContinue()
                (securedDismiss ?? dismiss)()
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.movo.surface)
        // Opaque sheet backing so the screen behind never shows through during
        // the present / dismiss slide (avoids the background appearing to animate).
        .presentationBackground(Color.movo.surface)
    }

    // MARK: - Disclaimer

    private func disclaimerText() -> some View {
        (
            Text("By selecting Continue, you agree to the ")
                .foregroundColor(Color.movo.textSecondary)
            + Text("Plaid End User Privacy Policy")
                .foregroundColor(Color.movo.textSecondary)
                .underline(true, color: Color.movo.borderStrong)
            + Text(".")
                .foregroundColor(Color.movo.textTertiary)
        )
        .font(.system(size: 12, weight: .regular))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            if let url = URL(string: "https://www.herringbank.com") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.movo.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)

                Text(description)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}
