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
        VStack(alignment: .leading, spacing: Spacing.xxl) {

            HStack {
                Spacer()
                CircularNavButton(systemName: "xmark") { (securedDismiss ?? dismiss)() }
                    .accessibilityLabel("Close")
                    .padding(.leading, Spacing.md)
            }
            .padding(.top, Spacing.lg)

            // Header — logos + close on one balanced row
            HStack(alignment: .center, spacing: 0) {

                // MOVO tile
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.elevated)
                    .frame(width: 48, height: 48)
                    .overlay(
                        MovoMVSymbol()
                            .frame(width: 28, height: 28)
                    )

                Spacer()

                // Dot connector — fills space between the two tiles
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.movo.border)
                            .frame(width: i == 2 ? 4 : 3, height: i == 2 ? 4 : 3)
                            .opacity(i == 2 ? 0.6 : 1)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                // Plaid tile
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("plaid")
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)
                    )

            }

            // Title
            Text("MOVO partners with Plaid to connect your accounts")
                .textStyle(Typography.heroTitle)
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
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xxl)
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
        .font(.system(size: 11, weight: .regular))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
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
