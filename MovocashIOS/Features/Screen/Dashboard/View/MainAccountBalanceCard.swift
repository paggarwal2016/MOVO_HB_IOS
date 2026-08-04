//
//  MainAccountBalanceCard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 03/08/26.
//

import SwiftUI

/// Green summary card shown at the top of the Dashboard, directly under the header.
/// Surfaces the PRIMARYACCOUNT label/balance/masked account number driven by the
/// dashboard API response, plus a CTA that opens the existing account details sheet.
struct MainAccountBalanceCard: View {

    let label: String
    let accountNumber: String
    let balance: Decimal
    let buttonLabel: String
    let onDetailsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .center) {
                Text(label.uppercased())
                    .textStyle(Typography.cardHero)
                    .foregroundColor(Color.movo.onAccent)

                Spacer()

                maskedLastFourText(accountNumber.suffix(4))
                    .foregroundColor(Color.movo.onAccent)
            }

            Spacer().frame(height: Spacing.xxs)

            BalanceText(amount: balance, dollarSize: 26, centsSize: 17, color: Color.movo.onAccent, centsOpacity: 1.0)

            Spacer().frame(height: Spacing.xs)

            HStack {
                Spacer()
                Button(action: onDetailsTap) {
                    Text(buttonLabel)
                        .textStyle(Typography.button)
                        .foregroundColor(Color.movo.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Color.movo.onAccent.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color.movo.accent, Color.movo.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
    }
}
