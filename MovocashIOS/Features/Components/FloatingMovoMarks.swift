//
//  FloatingMovoMarks.swift
//  MovocashIOS
//
//  Created by Vinu on 26/06/26.
//

import SwiftUI

/// Decorative background of Movo "M" marks scattered naturally around the top and
/// sides — never behind the center hero circle. Each mark drops in from above and
/// settles into place, staggered by `delay` so the field cascades top-to-bottom.
/// Standalone (separate from `SparkleDecorations`); cosmetic, non-interactive.
struct FloatingMovoMarks: View {

    /// Frame of the hero circle (in the shared coordinate space). Any mark whose
    /// position falls inside this circle is not drawn, so the small marks never
    /// overlap the large M. `.zero` disables the exclusion.
    var excludedCircle: CGRect = .zero

    private struct Mark: Identifiable {
        let id: Int
        let x: CGFloat       // fraction of width (ignored if `side` is set)
        let y: CGFloat       // fraction of height (ignored if `side` is set)
        let size: CGFloat
        let opacity: Double
        let delay: Double
        var rotation: Double = 0   // degrees, for a few tilted marks
        var side: Side? = nil      // when set, position locks to the hero circle instead of x/y
        var skipExclusion: Bool = false // when true, ignore the hero-proximity check
    }

    private enum Side {
        case left, right       // flanking the hero, vertically centered on it
        case aboveCenter       // sitting just above the hero's real top edge
    }

    /// Organic scatter across the full screen height, including a couple of marks
    /// flanking the hero circle (anchored to its real position via `side`, never
    /// behind it — see `isClear`) and a couple filling the gap just above it. Sizes
    /// range from 14 (small accents) up to 25, and roughly half the marks carry a
    /// slight tilt, the rest sit straight, for a natural hand-scattered mix. Delays
    /// increase with y so marks drop top-first, cascading downward.
    private let marks: [Mark] = [
        // -- top band --
        Mark(id: 0,  x: 0.27, y: 0.05, size: 22, opacity: 0.55, delay: 0.00, rotation: -12),
        Mark(id: 1,  x: 0.51, y: 0.04, size: 16, opacity: 0.42, delay: 0.04),
        Mark(id: 2,  x: 0.72, y: 0.06, size: 21, opacity: 0.48, delay: 0.06, rotation: 10),
        // -- upper third --
        Mark(id: 3,  x: 0.11, y: 0.14, size: 25, opacity: 0.58, delay: 0.10),
        Mark(id: 4,  x: 0.36, y: 0.13, size: 22, opacity: 0.50, delay: 0.12, rotation: -8),
        Mark(id: 5,  x: 0.61, y: 0.15, size: 15, opacity: 0.52, delay: 0.14),
        Mark(id: 6,  x: 0.84, y: 0.14, size: 24, opacity: 0.55, delay: 0.13, rotation: 14),
        // -- mid-upper --
        Mark(id: 7,  x: 0.19, y: 0.26, size: 21, opacity: 0.46, delay: 0.20),
        Mark(id: 8,  x: 0.45, y: 0.27, size: 20, opacity: 0.44, delay: 0.22, rotation: 9),
        Mark(id: 9,  x: 0.68, y: 0.25, size: 14, opacity: 0.48, delay: 0.21),
        Mark(id: 10, x: 0.88, y: 0.27, size: 20, opacity: 0.44, delay: 0.23, rotation: -10),
        // -- mid --
        Mark(id: 11, x: 0.08, y: 0.38, size: 20, opacity: 0.40, delay: 0.30, rotation: 7),
        Mark(id: 12, x: 0.33, y: 0.40, size: 16, opacity: 0.40, delay: 0.32),
        Mark(id: 13, x: 0.50, y: 0.39, size: 20, opacity: 0.42, delay: 0.31),
        Mark(id: 14, x: 0.81, y: 0.41, size: 19, opacity: 0.40, delay: 0.33, rotation: -9),
        // -- gap just above the hero circle --
        Mark(id: 15, x: 0.30, y: 0.47, size: 15, opacity: 0.38, delay: 0.36, rotation: 8),
        Mark(id: 16, x: 0.70, y: 0.47, size: 14, opacity: 0.36, delay: 0.37, rotation: -7),
        Mark(id: 17, x: 0, y: 0, size: 13.4, opacity: 0.34, delay: 0.38, side: .aboveCenter),
        // -- flanking the hero circle (anchored to its real frame, not a fraction) --
        Mark(id: 18, x: 0, y: 0, size: 20, opacity: 0.45, delay: 0.42, rotation: 11, side: .left),
        Mark(id: 19, x: 0, y: 0, size: 19, opacity: 0.42, delay: 0.43, rotation: -8, side: .right),
    ]

    /// Fades in shortly after the marks start falling, giving the hero circle a soft
    /// pulse of light to land into rather than a flat backdrop.
    @State private var glowVisible = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if excludedCircle != .zero {
                    RadialGradient(
                        colors: [Color.movo.accent.opacity(0.30),
                                 Color.movo.accent.opacity(0.10),
                                 Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: excludedCircle.width * 0.65
                    )
                    .frame(width: excludedCircle.width * 1.4, height: excludedCircle.width * 1.4)
                    .position(x: excludedCircle.midX, y: excludedCircle.midY)
                    .opacity(glowVisible ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.4).delay(0.25)) {
                            glowVisible = true
                        }
                    }
                }

                ForEach(marks) { mark in
                    if isClear(mark, in: geo.size) {
                        Image("herringMonogram")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(Color.movo.accent)
                            .frame(width: mark.size, height: mark.size)
                            .rotationEffect(.degrees(mark.rotation))
                            .modifier(DropInModifier(targetOpacity: mark.opacity,
                                                    delay: mark.delay))
                            .position(point(for: mark, in: geo.size))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Resolves a mark's on-screen point. Side-anchored marks lock to the hero
    /// circle's real frame — flanking marks sit just outside its left/right edge at
    /// its vertical center; above-hero marks sit just above its top edge, offset to
    /// either side — so they always land correctly regardless of where the hero
    /// actually sits on screen. Everything else uses its fixed x/y fraction.
    private func point(for mark: Mark, in size: CGSize) -> CGPoint {
        guard let side = mark.side, excludedCircle != .zero else {
            return CGPoint(x: mark.x * size.width, y: mark.y * size.height)
        }
        let gap: CGFloat = mark.size / 2 + 20
        switch side {
        case .left:
            return CGPoint(x: excludedCircle.minX - gap, y: excludedCircle.midY)
        case .right:
            return CGPoint(x: excludedCircle.maxX + gap, y: excludedCircle.midY)
        case .aboveCenter:
            return CGPoint(x: excludedCircle.midX, y: excludedCircle.minY - gap - 42)
        }
    }

    /// A mark is clear when it sits far enough from the excluded circle's center that
    /// it can't touch the large M (radius + half the mark + slack). Side-anchored
    /// marks are placed outside the circle by construction, so they always pass.
    private func isClear(_ mark: Mark, in size: CGSize) -> Bool {
        guard mark.side == nil else { return true }
        guard !mark.skipExclusion else { return true }
        guard excludedCircle != .zero else { return true }
        let center = CGPoint(x: excludedCircle.midX, y: excludedCircle.midY)
        let point = CGPoint(x: mark.x * size.width, y: mark.y * size.height)
        let minDistance = excludedCircle.width / 2 + mark.size / 2 + 56
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

// MARK: - Drop-in entrance

/// Drops each mark down from above its final position and fades it in — a clean
/// settle, no bounce. Runs once on appear; staggered by `delay` so marks cascade
/// top-to-bottom.
private struct DropInModifier: ViewModifier {
    let targetOpacity: Double
    let delay: Double

    @State private var visible = false
    @State private var settled = false

    func body(content: Content) -> some View {
        content
            .offset(y: settled ? 0 : -220)
            .opacity(visible ? targetOpacity : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                    visible = true
                }
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 40, damping: 14).delay(delay)) {
                    settled = true
                }
            }
    }
}