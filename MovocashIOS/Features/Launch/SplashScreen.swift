//
//  SplashScreen.swift
//  MovocashIOS
//
//  Pure visual splash. Routing decisions live in StartupRouter — this view
//  only renders while appState.flow == .splash during postBootstrap warmup.
//
//  The splash image is extracted as MovoSplashLogo so BiometricGateView
//  can reuse it in its splash mode (auto-trigger warm-transition state).
//  This guarantees pixel-perfect visual continuity between cold launch
//  and warm-transition re-auth screens.
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            // Pure black #000000 — fixed, not adaptive, so light mode cannot shift it.
            // Matches LaunchScreen.storyboard background exactly.
            Color.black.ignoresSafeArea()
            MovoSplashLogo()
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
    }
}

/// The Movo splash image, sized to match LaunchScreen.storyboard exactly.
/// Used in both SplashScreen (cold launch) and BiometricGateView's
/// splash mode (warm-transition re-auth). Static — no animation — so the
/// transition from LaunchScreen to SwiftUI splash is visually seamless.
struct MovoSplashLogo: View {

    // SYNC: keep splashWidth (231) in sync with the LaunchScreen.storyboard
    // herringSplash width constraint (231pt). Both sides must stay identical.
    private static let splashWidth: CGFloat = 231

    var body: some View {
        Image("herringSplash")
            .resizable()
            .scaledToFit()
            .frame(width: Self.splashWidth)
    }
}
