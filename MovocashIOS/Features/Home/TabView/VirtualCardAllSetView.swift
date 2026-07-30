//
//  VirtualCardAllSetView.swift
//  MovocashIOS
//
//  Confirmation screen shown after PIN is set for a virtual card.
//  Used in two flows:
//    1. Dashboard "Use existing PIN" / "Create new PIN" (default title/message)
//    2. KYC registration activate (custom title + message passed from KYCSuccessView)
//

import SwiftUI

struct VirtualCardAllSetView: View {

    /// Headline. Defaults to the PIN-set confirmation copy.
    var title: String = "You're all set"
    /// Body copy under the title.
    var message: String = "Your PIN is set and your digital cash card is ready to use."
    /// Finishes the flow ("Let's MOVO").
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            glyph

            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Color.movo.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .textStyle(Typography.subtitle)
                .foregroundStyle(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xs)

            Spacer(minLength: Spacing.xl)

            Button(action: onDone) {
                Text("Let\u{2019}s MOVO")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        .padding(.top, Spacing.md)
        .background(Color.movo.surface.ignoresSafeArea())
    }

    private var glyph: some View {
        ZStack(alignment: .topTrailing) {
            Image("CardFrontHerring")
                .resizable()
                .scaledToFit()
                .frame(width: 200)

            ZStack {
                Circle()
                    .fill(Color.movo.accent)
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.movo.onAccent)
            }
            .offset(x: 8, y: -8)
        }
        .padding(.bottom, Spacing.xl + 8)
    }
}
