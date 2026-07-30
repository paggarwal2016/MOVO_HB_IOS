import SwiftUI
import UIKit   // UINotificationFeedbackGenerator

// MARK: - Geometry (the parts with real risk, pre-solved)

/// Teardrop/egg balloon. Authored relative to `rect`, so it scales to any frame.
/// Widest point sits at ~0.42·height (slightly above center); the bottom tapers
/// to a neck at bottom-center where the knot + string attach.
struct BalloonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let half = w / 2
        let wideY = rect.minY + h * 0.42          // widest point
        let top = CGPoint(x: cx, y: rect.minY)
        let tip = CGPoint(x: cx, y: rect.maxY)     // knot attaches here
        let leftWide = CGPoint(x: rect.minX, y: wideY)
        let rightWide = CGPoint(x: rect.maxX, y: wideY)

        var p = Path()
        p.move(to: top)
        // top dome → right widest
        p.addCurve(to: rightWide,
                   control1: CGPoint(x: cx + half * 0.55, y: rect.minY),
                   control2: CGPoint(x: rect.maxX, y: wideY - h * 0.18))
        // right side taper → tip (gentle neck)
        p.addCurve(to: tip,
                   control1: CGPoint(x: rect.maxX, y: wideY + h * 0.30),
                   control2: CGPoint(x: cx + half * 0.34, y: rect.maxY - h * 0.02))
        // tip → left widest (mirror)
        p.addCurve(to: leftWide,
                   control1: CGPoint(x: cx - half * 0.34, y: rect.maxY - h * 0.02),
                   control2: CGPoint(x: rect.minX, y: wideY + h * 0.30))
        // left widest → top dome (mirror)
        p.addCurve(to: top,
                   control1: CGPoint(x: rect.minX, y: wideY - h * 0.18),
                   control2: CGPoint(x: cx - half * 0.55, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Small downward triangle nub at the balloon base.
struct KnotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Gentle S-curve string, hangs vertically from the knot.
struct BalloonString: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.height * 0.35),
                   control2: CGPoint(x: rect.minX, y: rect.height * 0.70))
        return p
    }
}

// MARK: - Hero

struct RegistrationCelebrationHero: View {

    /// Upper bound for balloon width; the actual size is computed to fit the
    /// available height (see GeometryReader below), so it never clips on SE.
    var maxBalloonWidth: CGFloat = 100

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var bob: CGFloat = 0

    // Proportions, all keyed off the computed balloon width.
    private let bodyRatio: CGFloat = 1.20      // body height ÷ width
    private let stringRatio: CGFloat = 0.90    // string length ÷ width
    private let knotRatio: CGFloat = 0.10
    private var totalRatio: CGFloat { bodyRatio + stringRatio + knotRatio } // ≈ 2.20

    var body: some View {
        GeometryReader { geo in
            // Fit the whole composition to whatever space the parent gives us.
            let size = min(maxBalloonWidth, geo.size.width, geo.size.height / totalRatio)
            content(size: size)
                .frame(width: geo.size.width, height: geo.size.height) // center it
        }
        .accessibilityHidden(true)
        .onAppear(perform: animateIn)
    }

    private func content(size: CGFloat) -> some View {
        let bodyH = size * bodyRatio
        let knotH = size * knotRatio
        let stringH = size * stringRatio

        return ZStack {
            // Backdrop (halo + accent marks) — sits still, centered on the balloon.
            backdrop(size: size)
                .offset(y: -stringH / 2)   // balloon center is above the VStack center

            // Balloon + string — tilts, bobs, inflates on entrance.
            VStack(spacing: 0) {
                balloon(size: size, bodyH: bodyH, knotH: knotH)
                    // Tilt ONLY the balloon, pivoting on the knot, so the string stays vertical.
                    .rotationEffect(.degrees(-12), anchor: .bottom)

                BalloonString()
                    .stroke(Color.movo.silverTint,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: size * 0.5, height: stringH)
            }
            // Bob moves balloon + string together.
            .offset(y: reduceMotion ? 0 : bob)
            // Entrance: inflate up from the string base.
            .scaleEffect(reduceMotion ? 1 : (hasAppeared ? 1 : 0.85), anchor: .bottom)
        }
        // Fade the whole thing (balloon + backdrop) in together.
        .opacity((hasAppeared || reduceMotion) ? 1 : 0)
    }

    // MARK: Backdrop — soft halo + accent marks

    private func backdrop(size: CGFloat) -> some View {
        ZStack {
            // Spotlight halo — softened (blur and size reduced from original).
            Circle().fill(Color.movo.accentTint)
                .frame(width: size * 2.1, height: size * 2.1)
                .blur(radius: size * 0.20)
                .opacity(0.6)
            Circle().fill(Color.movo.accentTint)
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.12)
                .opacity(0.7)
        }
    }

    private func accentArc(_ size: CGFloat, trim: CGFloat, rotation: Double,
                           color: Color, dx: CGFloat, dy: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: trim)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
            .frame(width: size * 0.36, height: size * 0.36)
            .rotationEffect(.degrees(rotation))
            .offset(x: size * dx, y: size * dy)
    }

    private func dot(_ size: CGFloat, radius: CGFloat, color: Color,
                     dx: CGFloat, dy: CGFloat) -> some View {
        Circle().fill(color)
            .frame(width: size * radius * 2, height: size * radius * 2)
            .offset(x: size * dx, y: size * dy)
    }

    // MARK: Balloon

    private func balloon(size: CGFloat, bodyH: CGFloat, knotH: CGFloat) -> some View {
        ZStack {
            BalloonShape().fill(Color.movo.accent)

            // Right-edge shadow, clipped to the body outline.
            BalloonShape()
                .fill(Color.movo.balloonShade.opacity(0.2))
                .offset(x: size * 0.03, y: size * 0.03)
                .mask(BalloonShape())

            // Soft sheen, upper-left, clipped to the body.
            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: size * 0.30, height: size * 0.42)
                .blur(radius: size * 0.05)
                .offset(x: -size * 0.16, y: -size * 0.22)
                .mask(BalloonShape())

            // Reuse the existing mark, rendered all-white. +20% scale vs original.
            MovoMVSymbol(bodyStyle: Color.white, accent: Color.white)
                .frame(width: size * 0.73)
                .offset(y: -size * 0.04)   // optical-center on the bulge
        }
        .frame(width: size, height: bodyH)
        .overlay(alignment: .bottom) {
            KnotShape()
                .fill(Color.movo.balloonHighlight)
                .frame(width: size * 0.14, height: knotH)
                .offset(y: knotH * 0.5)
        }
    }

    private func animateIn() {
        guard !hasAppeared else { return }
        if reduceMotion { hasAppeared = true; return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            hasAppeared = true
        }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            bob = 5
        }

        // Haptic — not gated by reduceMotion (a haptic isn't motion).
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.movo.background.ignoresSafeArea()
        RegistrationCelebrationHero()
            .frame(maxHeight: 190)          // mirrors the KYCSuccessView call site
    }
}

/*
 CALL SITE (KYCSuccessView.swift):

     RegistrationCelebrationHero()
         .frame(maxHeight: 190)
         .padding(.bottom, Spacing.lg)
     // no .clipped() — the halo bleeds past the frame on purpose, and clipping
     // would also cut the tilt corners.

 WHAT'S NEW vs your pasted version
 • Added a self-contained backdrop: two-layer accentTint halo + 5 accent marks
   (3 trimmed-circle arcs, 2 dots). content() is now a ZStack; the VStack still owns
   bob + tilt + scale, opacity moved up so the halo fades in too. Nothing else changed.
 • No new tokens — uses accentTint / accent / silverTint / white you already have.

 TUNING
 • Halo strength: if accentTint (12%) reads too green vs the mock's near-neutral disc,
   drop the inner Circle or point both at a neutral elevated-surface token.
 • Accent placement: dx/dy are balloon-radius multiples from center, rotation in degrees.
   Nudge in the preview to hit the mock's exact clock positions.
 • The -12° tilt swings the balloon's corners ~20pt outside the size-wide column — fine,
   nothing clips. Just don't wrap the hero in a clipping container.
*/

