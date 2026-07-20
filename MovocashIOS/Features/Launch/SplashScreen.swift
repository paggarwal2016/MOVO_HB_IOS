//
//  SplashScreen.swift
//  MovocashIOS
//
//  Pure visual splash. Routing decisions live in StartupRouter — this view
//  only renders while appState.flow == .splash during postBootstrap warmup.
//
//  The splash logo is extracted as MovoSplashLogo so BiometricGateView
//  can reuse it in its splash mode (auto-trigger warm-transition state).
//  This guarantees pixel-perfect visual continuity between cold launch
//  and warm-transition re-auth screens.
//

import SwiftUI

// NOTE: LaunchBackground.colorset and LaunchLogoTint.colorset in Assets.xcassets
// are manually coupled to DesignTokens.Palette.background and
// DesignTokens.Palette.textPrimary/textSecondary. The storyboard cannot read
// Swift tokens — if those token values ever change, update the colorsets to match.
struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.movo.background.ignoresSafeArea()
            MovoSplashLogo()
        }
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
    }
}

/// The Movo logo mark, sized and styled to match LaunchScreen.storyboard
/// exactly. Used in both SplashScreen (cold launch) and BiometricGateView's
/// splash mode (warm-transition re-auth). Static — no animation — so the
/// transition from LaunchScreen to SwiftUI splash is visually seamless.
struct MovoSplashLogo: View {
    var body: some View {
        MovoMVSymbol().frame(width: 120, height: 120)
    }
}
