//
//  FirstCardRewardView.swift
//  MovocashIOS
//

import SwiftUI

struct FirstCardRewardView: View {

    var onViewDetails: () -> Void = {}

    var onClose: () -> Void = {}

    @State private var shown = false

    var body: some View {
        ZStack {

            // Light glass background — a subtle blur with only a soft (~15%) light
            // fade toward the app background, so the dashboard stays ~85% visible.
            // No dark dimming — classy, premium focus on the card.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.movo.background.opacity(0.15))
                .ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .onTapGesture { animateOut { onClose() } }

            SparkleDecorations()
                .opacity(shown ? 1 : 0)

            rewardCard
                .scaleEffect(shown ? 1 : 0.8)
                .opacity(shown ? 1 : 0)
                .padding(Spacing.xl)
        }
        .background(ClearCoverBackground())
        .trackScreen(AnalyticsScreen.rewardUnlock)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { shown = true }
        }
    }

    // MARK: - Reward Card

    private var rewardCard: some View {
        VStack(spacing: Spacing.lg) {

            // Brand symbol centered, with the close button pinned top-right.
            ZStack {
                MovoMVSymbol()
                    .frame(width: 44, height: 44)
                
                Spacer()
            }

            // Reward eyebrow pill
            rewardPill

            Text("Your first digital cash card is on us.")
                .textStyle(Typography.cardHero)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("A free digital cash card you can use right away \u{2014} add it to Apple Pay in one tap.")
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { animateOut { onViewDetails() } }) {
                Text("Activate my card")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.xxl + Spacing.xs)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.movo.cardBorder, lineWidth: Stroke.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
    }

    // MARK: - Reward Pill

    private var rewardPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("REWARD UNLOCKED")
                .textStyle(Typography.eyebrow)
        }
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
    }

    // MARK: - Animation

    /// Contract the card back to center, then run the action (which removes the cover).
    private func animateOut(_ then: @escaping () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { then() }
    }
}

// MARK: - Clear cover background

/// Makes the hosting full-screen cover transparent so the dashboard shows through
/// behind the scrim instead of an opaque system background.
private struct ClearCoverBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { BackgroundClearingView() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class BackgroundClearingView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The cover's hosting view is two levels up; clear it so the dashboard
            // (dimmed only by our SwiftUI scrim) stays visible.
            superview?.superview?.backgroundColor = .clear
        }
    }
}
