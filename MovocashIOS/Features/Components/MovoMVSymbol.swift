//
//  MovoMVSymbol.swift
//  Movo
//
//  Created by tracing the official "MV" logomark.
//

import SwiftUI

/// Movo's "MV" logomark — a layered double-M composed of two layers:
/// a primary "body" (the outer M outline plus two inner legs), and a
/// secondary "chevron" (the floating inner V), tinted with the accent color.
///
/// The defaults match the official wordmark (dark navy body, teal chevron),
/// which is designed to sit on a light background. Override `color` when
/// rendering on dark surfaces:
///
/// ```swift
/// MovoMVSymbol()                                  // navy body + teal chevron — for light backgrounds
/// MovoMVSymbol(color: .white)                     // for dark backgrounds (splash, dark mode)
/// MovoMVSymbol(color: .white, accent: .yellow)    // fully custom
/// ```
///
/// The artwork's intrinsic aspect ratio (≈ 1.018) is preserved automatically;
/// it stays proportional and centered in any frame.
struct MovoMVSymbol: View {

    /// Intrinsic aspect ratio (width / height) of the original artwork.
    static let aspectRatio: CGFloat = 3717.0 / 3650.0

    /// Movo's brand body color (dark navy from the official wordmark).
    static let defaultBody = Color(red: 0x1A / 255.0,
                                   green: 0x1A / 255.0,
                                   blue: 0x22 / 255.0)

    /// Movo's signature teal accent.
    static let defaultAccent = Color(red: 0x62 / 255.0,
                                     green: 0x9F / 255.0,
                                     blue: 0x86 / 255.0)

    var color: Color
    var accent: Color

    init(color: Color = MovoMVSymbol.defaultBody,
         accent: Color = MovoMVSymbol.defaultAccent) {
        self.color = color
        self.accent = accent
    }

    var body: some View {
        ZStack {
            MovoMVBodyShape().fill(color)
            MovoMVChevronShape().fill(accent)
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
    }
}

// MARK: - Shapes

/// The primary body of the mark: outer M outline + two inner legs.
struct MovoMVBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width,
                    y: rect.minY + y * rect.height)
        }

        var path = Path()

        // 1. Outer M (the main thick "M" outline).
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

        // 2. Inner left leg (vertical pillar with chamfered top-right corner).
        path.move(to:    p(0.186, 0.573))
        path.addLine(to: p(0.186, 1.000))
        path.addLine(to: p(0.319, 1.000))
        path.addLine(to: p(0.319, 0.690))
        path.closeSubpath()

        // 3. Inner right leg (mirror of #2).
        path.move(to:    p(0.814, 0.573))
        path.addLine(to: p(0.681, 0.690))
        path.addLine(to: p(0.681, 1.000))
        path.addLine(to: p(0.814, 1.000))
        path.closeSubpath()

        return path
    }
}

/// The floating inner chevron — the V-shape that sits inside the outer notch.
struct MovoMVChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width,
                    y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to:    p(0.184, 0.329))   // top-left
        path.addLine(to: p(0.184, 0.494))   // bottom of outer-left edge
        path.addLine(to: p(0.500, 0.771))   // chevron's bottom V-tip
        path.addLine(to: p(0.816, 0.494))   // bottom of outer-right edge
        path.addLine(to: p(0.816, 0.329))   // top-right
        path.addLine(to: p(0.500, 0.604))   // top notch tip
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("MovoMVSymbol") {
    VStack(spacing: 32) {
        // Canonical: dark navy body + teal chevron on a LIGHT background
        // (matches the official wordmark).
        MovoMVSymbol()
            .padding(20)
            .frame(width: 160, height: 160)
            .background(.white, in: RoundedRectangle(cornerRadius: 32))

        // For dark backgrounds (splash, dark-mode icons), override to white.
        MovoMVSymbol(color: .white)
            .padding(20)
            .frame(width: 160, height: 160)
            .background(.black, in: RoundedRectangle(cornerRadius: 32))

        // A range of sizes on light.
        HStack(spacing: 20) {
            ForEach([24.0, 40.0, 64.0, 96.0], id: \.self) { size in
                MovoMVSymbol()
                    .frame(width: size, height: size)
            }
        }

        // Non-square frame — symbol stays proportional and centered.
        MovoMVSymbol()
            .frame(width: 240, height: 90)
            .border(.gray.opacity(0.2))
    }
    .padding()
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
