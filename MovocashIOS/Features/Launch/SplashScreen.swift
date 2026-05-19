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

struct SplashScreen: View {
    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            MovoSplashLogo()
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The Movo logo mark with a 0.6s scale-in animation, used in both
/// SplashScreen (cold launch) and BiometricGateView's splash mode
/// (warm-transition re-auth).
struct MovoSplashLogo: View {
    @State private var visible = false

    var body: some View {
        MovoLogoMark(size: 120, color: .white)
            .scaleEffect(visible ? 1 : 0.96)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    visible = true
                }
            }
    }
}
