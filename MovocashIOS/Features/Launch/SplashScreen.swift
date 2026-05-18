//
//  SplashScreen.swift
//  MovocashIOS
//
//  Pure visual splash. Routing decisions live in StartupRouter — this view
//  only renders while appState.flow == .splash during postBootstrap warmup.
//

import SwiftUI

struct SplashScreen: View {
    @State private var lockupVisible = false

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            MovoLogoMark(size: 120, color: .white)
                .scaleEffect(lockupVisible ? 1 : 0.96)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                lockupVisible = true
            }
        }
    }
}
