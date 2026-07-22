//
//  WaitlistSuccessView.swift
//  MovocashIOS
//
//  Created by Vinu on 26/06/26.
//

import SwiftUI

struct WaitlistSuccessView: View {
    let onDone: () -> Void

    /// Measured frame of the hero circle — fed to the background so its marks never
    /// overlap the large M.
    @State private var badgeFrame: CGRect = .zero

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            FloatingMovoMarks(excludedCircle: badgeFrame)

            VStack(spacing: 0) {

                Spacer(minLength: 0)

                // Hero — logo badge + title + message
                VStack(spacing: Spacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.movo.accent.opacity(0.12))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.movo.accent.opacity(0.18),
                                                  lineWidth: Stroke.thin)
                            )
                            .frame(width: 116, height: 116)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: BadgeFramePreferenceKey.self,
                                        value: proxy.frame(in: .named("waitlistSuccess"))
                                    )
                                }
                            )

                        AppLogo()
                            .frame(width: 52, height: 52)
                    }

                    VStack(spacing: Spacing.sm) {
                        Text("You're on the list")
                            .textStyle(Typography.heroTitle)
                            .foregroundColor(Color.movo.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("We'll text you the moment a spot opens up. No code needed to wait.")
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .frame(maxWidth: 300)
                    }
                }

                Spacer(minLength: 0)

                // Primary CTA pinned to the bottom
                Button("Got it") { onDone() }
                    .buttonStyle(MovoPrimaryButtonStyle())
                    .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .coordinateSpace(name: "waitlistSuccess")
        .onPreferenceChange(BadgeFramePreferenceKey.self) { badgeFrame = $0 }
        .background(Color.movo.background)
    }
}
