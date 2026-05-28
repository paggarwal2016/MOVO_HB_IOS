//
//  MovoMVSymbol.swift
//  MovocashIOS
//
//  Created by Vinu on 12/05/26.
//

import Foundation
import SwiftUI

// MARK: - MV Symbol (Canvas-drawn, scales to any size)

/// Movo's "MV" logomark — a layered double-M composed of four disjoint pieces:
/// an outer M outline, a floating inner chevron, and two inner legs with
/// chamfered (slanted) tops.
///
/// Use any of SwiftUI's standard fill / foreground modifiers to color it:
///
/// ```swift
/// MovoMVSymbol()
///     .fill(.white)
///     .frame(width: 44, height: 44)
///     .background(.black, in: RoundedRectangle(cornerRadius: 10))
/// ```
///
/// The artwork's intrinsic aspect ratio is ≈ 1.018 (very slightly wider than tall).
/// It is centered inside the available rect with that aspect ratio preserved, so
/// the symbol stays proportional regardless of how the parent frames it.

struct MovoMVSymbol: Shape {

    /// Intrinsic aspect ratio (width / height) of the original artwork.
    static let aspectRatio: CGFloat = 3717.0 / 3650.0

    func path(in rect: CGRect) -> Path {
        // Fit the symbol's aspect ratio inside `rect`, centered.
        let target: CGSize
        if rect.width / rect.height > Self.aspectRatio {
            target = CGSize(width: rect.height * Self.aspectRatio,
                            height: rect.height)
        } else {
            target = CGSize(width: rect.width,
                            height: rect.width / Self.aspectRatio)
        }
        let origin = CGPoint(
            x: rect.midX - target.width / 2,
            y: rect.midY - target.height / 2
        )

        // Maps a normalized (x, y) ∈ [0,1]² into the fitted rect.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * target.width,
                    y: origin.y + y * target.height)
        }

        var path = Path()

        // 1. Outer M (the main thick "M" outline — single connected piece).
        path.move(to:    p(0.000, 0.000))   // top-left corner
        path.addLine(to: p(0.000, 1.000))   // bottom-left corner
        path.addLine(to: p(0.128, 1.000))   // bottom of inner edge, left pillar
        path.addLine(to: p(0.128, 0.200))   // left shoulder
        path.addLine(to: p(0.500, 0.522))   // V-tip (where the diagonals meet)
        path.addLine(to: p(0.872, 0.200))   // right shoulder
        path.addLine(to: p(0.872, 1.000))   // bottom of inner edge, right pillar
        path.addLine(to: p(1.000, 1.000))   // bottom-right corner
        path.addLine(to: p(1.000, 0.000))   // top-right corner
        path.addLine(to: p(0.891, 0.000))   // top of right diagonal
        path.addLine(to: p(0.500, 0.357))   // top V-notch tip
        path.addLine(to: p(0.109, 0.000))   // top of left diagonal
        path.closeSubpath()

        // 2. Floating inner chevron (the V-shape sitting inside the outer notch).
        path.move(to:    p(0.184, 0.329))   // top-left
        path.addLine(to: p(0.184, 0.494))   // bottom of outer-left edge
        path.addLine(to: p(0.500, 0.771))   // chevron's bottom V-tip
        path.addLine(to: p(0.816, 0.494))   // bottom of outer-right edge
        path.addLine(to: p(0.816, 0.329))   // top-right
        path.addLine(to: p(0.500, 0.604))   // top notch tip
        path.closeSubpath()

        // 3. Inner left leg (vertical pillar with chamfered top-right corner).
        path.move(to:    p(0.186, 0.573))   // top-left
        path.addLine(to: p(0.186, 1.000))   // bottom-left
        path.addLine(to: p(0.319, 1.000))   // bottom-right
        path.addLine(to: p(0.319, 0.690))   // top-right (slanted edge starts here)
        path.closeSubpath()

        // 4. Inner right leg (mirror of #3).
        path.move(to:    p(0.814, 0.573))   // top-right
        path.addLine(to: p(0.681, 0.690))   // top-left (slanted edge ends here)
        path.addLine(to: p(0.681, 1.000))   // bottom-left
        path.addLine(to: p(0.814, 1.000))   // bottom-right
        path.closeSubpath()

        return path
    }
}



struct AmbientGlowView: View {
    
    var color: Color = .movo.accent
    var size: CGFloat = 400
    var opacity: Double = 0.08
    var blurRadius: CGFloat = 60
    var yOffset: CGFloat = -240
    
    var body: some View {
        color
            .opacity(opacity)
            .frame(width: size, height: size)
            .blur(radius: blurRadius)
            .offset(y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}
