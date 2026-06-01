//
//  CashCardCreateSuccess.swift
//  MovocashIOS
//
//  Created by Vinu on 01/06/26.
//

import SwiftUI

/// Shown after a virtual card is successfully created. Presents the new card and
/// its key details. The single "Done" CTA dismisses the screen.
struct CashCardCreateSuccess: View {

    /// Cardholder display name, e.g. "PRIYANKA S.".
    let cardHolder: String
    /// Last four digits of the card number, e.g. "4821".
    let lastFour: String
    /// Expiry in MM/YY form, e.g. "05/30".
    let expiry: String
    /// Linked account description, e.g. "Primary Checking ••3102".
    let linkedTo: String

    var cardType: String   = "Virtual debit"
    var status: String     = "Active"
    var spendLimit: String = "No limit set"

    /// Invoked when the user taps "Done".
    var onDone: () -> Void = {}

    // MARK: - Body

    var body: some View {
        ZStack {

            SuccessBackdrop()

            VStack(spacing: 0) {

                Spacer().frame(height: Spacing.huge + Spacing.xxl) // 64pt

                CheckmarkHalo()
                    .frame(width: 88, height: 88)

                Spacer().frame(height: Spacing.xxl)

                Text("Card created!")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.accent)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.movo.accentTint)
                            .overlay(
                                Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                            )
                    )

                Text("Your virtual debit card is ready. Add it to Apple Wallet anytime.")
                    .foregroundColor(Color.movo.textTertiary)
                    .textStyle(Typography.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.huge)

                Spacer().frame(height: Spacing.xl)

                cardVisual
                    .padding(.horizontal, Spacing.xl)

                Spacer().frame(height: Spacing.lg)

                detailCard
                    .padding(.horizontal, Spacing.xl)

                Spacer()

                // MARK: - CTA

                Button(action: onDone) {
                    Text("Done")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
        }
    }

    // MARK: - Card Visual

    private var cardVisual: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                )

            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Text("MOVO")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Color.movo.accent)
                    Spacer()
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(Color.movo.elevated)
                        .frame(width: 38, height: 28)
                }

                Spacer().frame(height: Spacing.xxl)

                Text("••••  ••••  ••••  \(lastFour)")
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .tracking(1)
                    .foregroundColor(Color.movo.textPrimary)

                Spacer().frame(height: Spacing.xl)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARD HOLDER")
                            .textStyle(Typography.micro)
                            .foregroundColor(Color.movo.textTertiary)
                        Text(cardHolder)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.movo.textPrimary)
                    }

                    Spacer().frame(width: Spacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPIRES")
                            .textStyle(Typography.micro)
                            .foregroundColor(Color.movo.textTertiary)
                        Text(expiry)
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundColor(Color.movo.textPrimary)
                    }

                    Spacer()

                    MastercardMark()
                }
            }
            .padding(Spacing.lg)
        }
        .frame(height: 200)
    }

    // MARK: - Detail Card

    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow("Card type", value: .text(cardType))
            divider
            detailRow("Linked to", value: .text(linkedTo))
            divider
            detailRow("Status", value: .statusPill(status))
            divider
            detailRow("Spend limit", value: .text(spendLimit))
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard))
    }

    private enum DetailValue {
        case text(String)
        case statusPill(String)
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: DetailValue) -> some View {
        HStack {
            Text(label)
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textTertiary)
            Spacer()
            switch value {
            case .text(let text):
                Text(text)
                    .textStyle(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.movo.textPrimary)
            case .statusPill(let text):
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.movo.accent)
                        .frame(width: 6, height: 6)
                    Text(text)
                        .textStyle(Typography.captionSmall)
                        .foregroundColor(Color.movo.accent)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    Capsule()
                        .fill(Color.movo.accentTint)
                        .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.movo.border)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Mastercard Mark

    private struct MastercardMark: View {
        var body: some View {
            HStack(spacing: -8) {
                Circle()
                    .fill(Color(red: 0.92, green: 0.30, blue: 0.20))
                    .frame(width: 26, height: 26)
                Circle()
                    .fill(Color(red: 0.95, green: 0.62, blue: 0.11))
                    .frame(width: 26, height: 26)
                    .opacity(0.9)
            }
        }
    }

    // MARK: - Backdrop

    private struct SuccessBackdrop: View {
        var body: some View {
            RadialGradient(
                colors: [
                    Color.movo.accent.opacity(0.14),
                    Color.movo.background
                ],
                center: UnitPoint(x: 0.5, y: 0.20),
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }
}
