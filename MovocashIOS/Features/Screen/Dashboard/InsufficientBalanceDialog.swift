//
//  InsufficientBalanceDialog.swift
//  MovocashIOS
//
//  Centered modal shown when the user taps "+" to create a card but has zero
//  available balance. Replaces the legacy ToastManager "Insufficient balance" prompt.
//

import SwiftUI

struct InsufficientBalanceDialog: View {

    /// Live available balance from the primary account.
    let balance: Decimal
    /// Triggers the appropriate add-money flow (Plaid link or Fund screen).
    let onAddMoney: () -> Void
    /// Dismisses without action.
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {

                cardIcon
                    .padding(.bottom, Spacing.xl)

                Text("Add money to create\nyour MOVOCASH card")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                Text("A new card needs a balance to get started.\nAdd at least $5 to continue.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)

                // Current balance row
                HStack {
                    Text("Available balance")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                    BalanceText(
                        amount: balance,
                        dollarSize: 16,
                        centsSize: 12,
                        color: Color.movo.textPrimary,
                        centsOpacity: 0.7
                    )
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .fill(Color.movo.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card)
                                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                        )
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)

                // Primary CTA
                Button(action: onAddMoney) {
                    Text("Add money")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)

                // Secondary
                Button(action: onDismiss) {
                    Text("Not now")
                        .textStyle(Typography.body)
                        .foregroundColor(Color.movo.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .padding(.top, Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: Radius.sheet)
                    .fill(Color.movo.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sheet)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
            )
            .padding(.horizontal, Spacing.xxl)
        }
    }

    // MARK: - Card icon

    private var cardIcon: some View {
        ZStack(alignment: .bottomTrailing) {

            Image(systemName: "creditcard.fill")
                .font(.system(size: 52, weight: .regular))
                .foregroundColor(Color.movo.accent)
                .padding(.bottom, Spacing.sm)
                .padding(.trailing, Spacing.sm)

            // MovoMVSymbol badge overlapping bottom-right
            ZStack {
                Circle()
                    .fill(Color.movo.elevated)
                    .overlay(Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
                    .frame(width: 28, height: 28)

                Image("herringLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
        }
    }
}
