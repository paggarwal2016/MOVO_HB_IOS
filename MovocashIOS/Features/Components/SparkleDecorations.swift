//
//  SparkleDecorations.swift
//  MovocashIOS
//

import SwiftUI

struct SparkleDecorations: View {

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Top-left cluster
                sparkle(size: 28).position(x: 40,      y: 80)
                sparkle(size: 16).position(x: 80,      y: 50)
                sparkle(size: 12).position(x: 30,      y: 130)

                // Top-right cluster
                sparkle(size: 24).position(x: w - 40,  y: 70)
                sparkle(size: 14).position(x: w - 75,  y: 40)
                sparkle(size: 10).position(x: w - 30,  y: 120)

                // Bottom-left cluster
                sparkle(size: 20).position(x: 50,      y: h - 160)
                sparkle(size: 12).position(x: 25,      y: h - 200)

                // Bottom-right cluster
                sparkle(size: 22).position(x: w - 50,  y: h - 170)
                sparkle(size: 13).position(x: w - 80,  y: h - 210)
                sparkle(size: 9) .position(x: w - 25,  y: h - 230)
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkle(size: CGFloat) -> some View {
        Text("✦")
            .font(.system(size: size))
            .foregroundColor(Color.movo.textTertiary.opacity(0.85))
    }
}
