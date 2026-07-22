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

            // Header — co-brand overlapping circles (Chime style); close pinned top-right.
            ZStack {
                // Back circle: Plaid — elevatedHigh, sits behind
                Circle()
                    .fill(Color.movo.elevatedHigh)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image("plaid")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(Color.movo.textPrimary)
                            .frame(width: 34, height: 34)
                    )
                    .offset(x: 22)

                // Front circle: Movo — dark elevated + accent tint + separator ring
                Circle()
                    .fill(Color.movo.elevated)
                    .overlay(Circle().fill(Color.movo.accent.opacity(0.12)))
                    .overlay(Circle().strokeBorder(Color.movo.surface, lineWidth: 1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        AppLogo()
                            .frame(width: 34, height: 34)
                    )
                    .offset(x: -22)
            }
            .frame(width: 108, height: 64)
            .frame(maxWidth: .infinity, alignment: .leading)
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
          //qw  disclaimerText()

            // Continue CTA — dismiss this sheet first, then let the parent start
            // Plaid (see PlaidLinkFlowModifier wired on the parent).
            Button("Continue") {
                onContinue()
                (securedDismiss ?? dismiss)()
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.movo.surface)
        // Opaque sheet backing so the screen behind never shows through during
        // the present / dismiss slide (avoids the background appearing to animate).
        .presentationBackground(Color.movo.surface)
    }

    // MARK: - Disclaimer

    

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
