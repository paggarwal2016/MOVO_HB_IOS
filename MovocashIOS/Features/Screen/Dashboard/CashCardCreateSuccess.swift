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

    /// The newly created card whose details are shown.
    let card: VCardListResponse

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
                
                Spacer().frame(height: Spacing.xxl)

                Text("Your virtual cash card is ready.\nAdd it to Apple Wallet anytime.")
                    .foregroundColor(Color.movo.textTertiary)
                    .textStyle(Typography.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.huge)

                Spacer().frame(height: Spacing.xxl)

                cardVisual
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
        // Reuse the shared, brand-locked card art so this screen stays in
        // sync with CardDetailSheet's hero.
        CardDetailSheet.MovoCardHero(card: card)
            .frame(width: 220)
            .frame(maxWidth: .infinity)
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
