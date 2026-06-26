//
//  FloatingMovoMarks.swift
//  MovocashIOS
//
//  Created by Vinu on 26/06/26.
//

import SwiftUI

/// Decorative background of Movo "M" marks scattered naturally around the top and
/// sides — never behind the center hero circle. Every mark drifts with a light,
/// slow float on its own phase, so the field gently breathes rather than moving in
/// lockstep. Standalone (separate from `SparkleDecorations`); cosmetic, non-interactive.
struct FloatingMovoMarks: View {

    /// Frame of the hero circle (in the shared coordinate space). Any mark whose
    /// position falls inside this circle is not drawn, so the small marks never
    /// overlap the large M. `.zero` disables the exclusion.
    var excludedCircle: CGRect = .zero

    private struct Mark: Identifiable {
        let id: Int
        let x: CGFloat       // fraction of width
        let y: CGFloat       // fraction of height
        let size: CGFloat
        let opacity: Double
        let amplitude: CGFloat
        let duration: Double
        let delay: Double
    }

    /// Organic, intentionally uneven placement. The center column is kept clear below
    /// the top edge so nothing sits behind the hero circle (~x 0.5, lower-middle).
    private let marks: [Mark] = [
        Mark(id: 0,  x: 0.50, y: 0.06, size: 28, opacity: 0.65, amplitude: 5, duration: 2.8, delay: 0.0),
        Mark(id: 1,  x: 0.14, y: 0.11, size: 26, opacity: 0.55, amplitude: 4, duration: 3.2, delay: 0.4),
        Mark(id: 2,  x: 0.31, y: 0.08, size: 17, opacity: 0.45, amplitude: 4, duration: 2.6, delay: 0.8),
        Mark(id: 3,  x: 0.69, y: 0.09, size: 20, opacity: 0.50, amplitude: 5, duration: 3.0, delay: 0.2),
        Mark(id: 4,  x: 0.86, y: 0.14, size: 25, opacity: 0.55, amplitude: 4, duration: 2.9, delay: 0.6),
        Mark(id: 5,  x: 0.22, y: 0.21, size: 15, opacity: 0.40, amplitude: 3, duration: 3.3, delay: 1.0),
        Mark(id: 6,  x: 0.80, y: 0.23, size: 19, opacity: 0.45, amplitude: 4, duration: 2.7, delay: 0.3),
        Mark(id: 7,  x: 0.11, y: 0.31, size: 21, opacity: 0.50, amplitude: 4, duration: 3.1, delay: 0.7),
        Mark(id: 8,  x: 0.90, y: 0.33, size: 16, opacity: 0.40, amplitude: 3, duration: 2.8, delay: 1.1),
        Mark(id: 9,  x: 0.14, y: 0.44, size: 18, opacity: 0.45, amplitude: 4, duration: 3.0, delay: 0.5),
        Mark(id: 10, x: 0.87, y: 0.45, size: 20, opacity: 0.45, amplitude: 4, duration: 2.9, delay: 0.9),

        // Inner ring above the circle (the previously-empty gaps).
        Mark(id: 11, x: 0.38, y: 0.30, size: 18, opacity: 0.48, amplitude: 4, duration: 3.0, delay: 0.35),
        Mark(id: 12, x: 0.63, y: 0.30, size: 16, opacity: 0.45, amplitude: 3, duration: 2.7, delay: 0.85),
        Mark(id: 13, x: 0.38, y: 0.43, size: 20, opacity: 0.50, amplitude: 4, duration: 3.1, delay: 0.60),
        Mark(id: 14, x: 0.63, y: 0.43, size: 17, opacity: 0.45, amplitude: 4, duration: 2.8, delay: 0.15)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(marks) { mark in
                    if isClear(mark, in: geo.size) {
                        MovoMVSymbol(
                            bodyStyle: Color.movo.accent,
                            accent: Color.movo.accent
                        )
                        .frame(width: mark.size, height: mark.size)
                        .opacity(mark.opacity)
                        .modifier(FloatModifier(amplitude: mark.amplitude,
                                                duration: mark.duration,
                                                delay: mark.delay))
                        .position(x: mark.x * geo.size.width, y: mark.y * geo.size.height)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// A mark is clear when it sits far enough from the excluded circle's center that
    /// neither it nor its float can touch the large M (radius + half the mark + slack).
    private func isClear(_ mark: Mark, in size: CGSize) -> Bool {
        guard excludedCircle != .zero else { return true }
        let center = CGPoint(x: excludedCircle.midX, y: excludedCircle.midY)
        let point = CGPoint(x: mark.x * size.width, y: mark.y * size.height)
        let minDistance = excludedCircle.width / 2 + mark.size / 2 + mark.amplitude + 8
        return hypot(point.x - center.x, point.y - center.y) > minDistance
    }
}

// MARK: - Hero circle frame reporting

/// Captures the hero circle's frame so the background can carve out an exclusion zone.
struct BadgeFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - Light float

/// Eases a mark up and down by a small `amplitude` forever, offset by `delay` so each
/// mark floats on its own phase. Kept slow and minimal for a gentle hover.
private struct FloatModifier: ViewModifier {
    let amplitude: CGFloat
    let duration: Double
    let delay: Double

    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : amplitude)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    up = true
                }
            }
    }
}
