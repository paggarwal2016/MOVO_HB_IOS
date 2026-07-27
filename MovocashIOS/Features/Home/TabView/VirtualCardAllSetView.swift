//
//  VirtualCardAllSetView.swift
//  MovocashIOS
//
//  "You're all set!" confirmation shown after the user chooses "Use existing PIN"
//  for their virtual card (product mockup, screen 2a).
//

import SwiftUI

struct VirtualCardAllSetView: View {

    /// Body copy under the title. Defaults to the "Use existing PIN" wording;
    /// the registration activate flow passes an activate-specific message.
    var message = "Your virtual card is using the same PIN as your first MOVO card."
    /// Finishes the flow ("Let's MOVO").
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)

            glyph

            Text("You\u{2019}re all set!")
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
        ZStack {
            Circle()
                .fill(Color.movo.accentTint)
                .frame(width: 128, height: 128)
            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.movo.accent)
        }
        .padding(.bottom, Spacing.xl)
    }
}
