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
        VStack(spacing: 0) {

            Spacer().frame(height: Spacing.xxxl)

            CheckmarkHalo()
                .frame(width: 88, height: 88)

            Spacer().frame(height: Spacing.xxl)

            Text("Your MOVOCASH card created!")
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
                .padding(.horizontal, Spacing.xl)

            Spacer().frame(height: Spacing.xxxl)

            // MARK: - CTA

            Button(action: onDone) {
                Text("LET'S MOVO!")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(
            ZStack {
                Color.movo.background
                RadialGradient(
                    colors: [
                        Color.movo.accent.opacity(0.14),
                        Color.movo.background
                    ],
                    center: UnitPoint(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet))
    }
}
