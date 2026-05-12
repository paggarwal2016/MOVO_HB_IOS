//
//  MovoIllustrations.swift
//  MovoCash
//
//  Hand-drawn SwiftUI icon illustrations for onboarding and beyond.
//  All glyphs are authored on a 24×24 grid and stroke-based, so they
//  render crisp at any size.
//
//  Each icon takes `stroke` and `accent` colors as parameters. Defaults
//  reference Color.movo (the primary palette per design
//  spec); callers in light-mode contexts pass PaletteLight tokens
//  explicitly via a theme resolver. This keeps icons palette-agnostic.
//
//  Usage:
//      ShieldKeyholeIcon()                                  // dark defaults
//      ShieldKeyholeIcon(stroke: theme.accent,              // reviewed state
//                        accent: theme.accent)
//

import SwiftUI

// MARK: - 24-grid coordinate helper

/// Icon paths are authored on a 24×24 grid. Multiply raw coordinates by
/// `s = rect.width / 24` to scale them into the actual draw rect.
private func s(_ rect: CGRect) -> CGFloat { rect.width / 24.0 }

// MARK: - ShieldKeyholeIcon — Privacy Policy

public struct ShieldKeyholeIcon: View {
    public var size: CGFloat = 22
    public var stroke: Color = Color.movo.textTertiary
    public var accent: Color = Color.movo.textPrimary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 22,
        stroke: Color = Color.movo.textTertiary,
        accent: Color = Color.movo.textPrimary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.stroke = stroke
        self.accent = accent
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            ShieldShape().fill(stroke.opacity(0.06))
            ShieldShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
            KeyholeShape().stroke(accent, style: .init(lineWidth: lineWidth + 0.1, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Privacy")
    }
}

// MARK: - HerringShieldIcon — Herring Bank Privacy Policy
//  Subtle stacked wave motif inside the shield — a quiet nod to "herring."

public struct HerringShieldIcon: View {
    public var size: CGFloat = 22
    public var stroke: Color = Color.movo.textTertiary
    public var accent: Color = Color.movo.textPrimary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 22,
        stroke: Color = Color.movo.textTertiary,
        accent: Color = Color.movo.textPrimary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.stroke = stroke
        self.accent = accent
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            ShieldShape().fill(stroke.opacity(0.06))
            ShieldShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
            HerringWaveShape(yOffset: 11)
                .stroke(accent, style: .init(lineWidth: lineWidth, lineCap: .round))
            HerringWaveShape(yOffset: 14)
                .stroke(accent.opacity(0.6), style: .init(lineWidth: lineWidth, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Bank privacy")
    }
}

// MARK: - DocumentLinesIcon — Terms of Use

public struct DocumentLinesIcon: View {
    public var size: CGFloat = 22
    public var stroke: Color = Color.movo.textTertiary
    public var accent: Color = Color.movo.textPrimary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 22,
        stroke: Color = Color.movo.textTertiary,
        accent: Color = Color.movo.textPrimary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.stroke = stroke
        self.accent = accent
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            DocumentShape().fill(stroke.opacity(0.06))
            DocumentShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
            DocumentFoldShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
            DocumentTextLinesShape()
                .stroke(accent, style: .init(lineWidth: lineWidth - 0.4, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Terms")
    }
}

// MARK: - SignatureIcon — Electronic Consent

public struct SignatureIcon: View {
    public var size: CGFloat = 22
    public var stroke: Color = Color.movo.textTertiary
    public var accent: Color = Color.movo.textPrimary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 22,
        stroke: Color = Color.movo.textTertiary,
        accent: Color = Color.movo.textPrimary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.stroke = stroke
        self.accent = accent
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            SignatureStrokeShape()
                .stroke(accent, style: .init(lineWidth: lineWidth + 0.1, lineCap: .round, lineJoin: .round))
            SignatureBaselineShape()
                .stroke(stroke.opacity(0.6), style: .init(lineWidth: lineWidth - 0.3, lineCap: .round))
            SignatureDotShape().fill(accent)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sign")
    }
}

// MARK: - ShieldCheckIcon — Eligibility section header

public struct ShieldCheckIcon: View {
    public var size: CGFloat = 20
    public var tint: Color = Color.movo.accent
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 20,
        tint: Color = Color.movo.accent,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            ShieldShape().fill(tint.opacity(0.08))
            ShieldShape().stroke(tint, style: .init(lineWidth: lineWidth, lineJoin: .round))
            SmallCheckShape()
                .stroke(tint, style: .init(lineWidth: lineWidth + 0.2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Eligibility")
    }
}

// MARK: - DocumentBadgeIcon — Documents section header

public struct DocumentBadgeIcon: View {
    public var size: CGFloat = 20
    public var stroke: Color = Color.movo.textTertiary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 20,
        stroke: Color = Color.movo.textTertiary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.stroke = stroke
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            DocumentShape().fill(stroke.opacity(0.06))
            DocumentShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
            DocumentFoldShape().stroke(stroke, style: .init(lineWidth: lineWidth, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Documents")
    }
}

// MARK: - EligibilityCheckIcon — small circle-check for eligibility rows

public struct EligibilityCheckIcon: View {
    public var size: CGFloat = 18
    public var tint: Color = Color.movo.accent
    public var lineWidth: CGFloat = DesignTokens.Stroke.thin

    public init(
        size: CGFloat = 18,
        tint: Color = Color.movo.accent,
        lineWidth: CGFloat = DesignTokens.Stroke.thin
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.10))
            Circle().strokeBorder(tint.opacity(0.6), lineWidth: lineWidth)
            EligibilityCheckShape()
                .stroke(tint, style: .init(lineWidth: lineWidth + 0.7, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Met")
    }
}

// MARK: - ReviewedCheckPill — solid green check (reviewed state)

public struct ReviewedCheckPill: View {
    public var size: CGFloat = 26
    public var fill: Color = Color.movo.accent
    public var checkColor: Color = Color.movo.background

    public init(
        size: CGFloat = 26,
        fill: Color = Color.movo.accent,
        checkColor: Color = Color.movo.background
    ) {
        self.size = size
        self.fill = fill
        self.checkColor = checkColor
    }

    public var body: some View {
        ZStack {
            Circle().fill(fill)
            PillCheckShape()
                .stroke(checkColor, style: .init(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.55, height: size * 0.55)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Reviewed")
    }
}

// MARK: - UnreadChevronIcon — chevron-right (unread state, signals "tap to open")

public struct UnreadChevronIcon: View {
    public var size: CGFloat = 14
    public var tint: Color = Color.movo.textTertiary
    public var lineWidth: CGFloat = DesignTokens.Stroke.thick

    public init(
        size: CGFloat = 14,
        tint: Color = Color.movo.textTertiary,
        lineWidth: CGFloat = DesignTokens.Stroke.thick
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ChevronRightShape()
            .stroke(tint, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityLabel("Open")
    }
}

// MARK: - BackChevronIcon — nav-bar back affordance

public struct BackChevronIcon: View {
    public var size: CGFloat = 18
    public var tint: Color = Color.movo.textTertiary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 18,
        tint: Color = Color.movo.textTertiary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ChevronLeftShape()
            .stroke(tint, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityLabel("Back")
    }
}

// MARK: - Shapes (private)

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 12 * u, y: 2 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 5 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 11 * u))
        p.addCurve(
            to: CGPoint(x: 12 * u, y: 22 * u),
            control1: CGPoint(x: 19 * u, y: 15.5 * u),
            control2: CGPoint(x: 16 * u, y: 19.5 * u)
        )
        p.addCurve(
            to: CGPoint(x: 5 * u, y: 11 * u),
            control1: CGPoint(x: 8 * u, y: 19.5 * u),
            control2: CGPoint(x: 5 * u, y: 15.5 * u)
        )
        p.addLine(to: CGPoint(x: 5 * u, y: 5 * u))
        p.closeSubpath()
        return p
    }
}

private struct KeyholeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.addEllipse(in: CGRect(x: (12 - 1.8) * u, y: (11 - 1.8) * u, width: 3.6 * u, height: 3.6 * u))
        p.move(to: CGPoint(x: 12 * u, y: 12.8 * u))
        p.addLine(to: CGPoint(x: 12 * u, y: 15.5 * u))
        return p
    }
}

private struct HerringWaveShape: Shape {
    let yOffset: CGFloat
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 7.5 * u, y: yOffset * u))
        p.addQuadCurve(
            to: CGPoint(x: 11.5 * u, y: yOffset * u),
            control: CGPoint(x: 9.5 * u, y: (yOffset - 1.5) * u)
        )
        p.addQuadCurve(
            to: CGPoint(x: 15.5 * u, y: yOffset * u),
            control: CGPoint(x: 13.5 * u, y: (yOffset + 1.5) * u)
        )
        return p
    }
}

private struct DocumentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 7 * u, y: 3 * u))
        p.addLine(to: CGPoint(x: 14 * u, y: 3 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 8 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 20 * u))
        p.addCurve(
            to: CGPoint(x: 18 * u, y: 21 * u),
            control1: CGPoint(x: 19 * u, y: 20.55 * u),
            control2: CGPoint(x: 18.55 * u, y: 21 * u)
        )
        p.addLine(to: CGPoint(x: 7 * u, y: 21 * u))
        p.addCurve(
            to: CGPoint(x: 6 * u, y: 20 * u),
            control1: CGPoint(x: 6.45 * u, y: 21 * u),
            control2: CGPoint(x: 6 * u, y: 20.55 * u)
        )
        p.addLine(to: CGPoint(x: 6 * u, y: 4 * u))
        p.addCurve(
            to: CGPoint(x: 7 * u, y: 3 * u),
            control1: CGPoint(x: 6 * u, y: 3.45 * u),
            control2: CGPoint(x: 6.45 * u, y: 3 * u)
        )
        p.closeSubpath()
        return p
    }
}

private struct DocumentFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 14 * u, y: 3 * u))
        p.addLine(to: CGPoint(x: 14 * u, y: 8 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 8 * u))
        return p
    }
}

private struct DocumentTextLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 9 * u, y: 12 * u));  p.addLine(to: CGPoint(x: 15 * u, y: 12 * u))
        p.move(to: CGPoint(x: 9 * u, y: 15 * u));  p.addLine(to: CGPoint(x: 15 * u, y: 15 * u))
        p.move(to: CGPoint(x: 9 * u, y: 18 * u));  p.addLine(to: CGPoint(x: 13 * u, y: 18 * u))
        return p
    }
}

private struct SignatureStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 4 * u, y: 17 * u))
        p.addQuadCurve(to: CGPoint(x: 9 * u, y: 15 * u),    control: CGPoint(x: 6 * u, y: 14 * u))
        p.addQuadCurve(to: CGPoint(x: 13.5 * u, y: 13.5 * u), control: CGPoint(x: 12 * u, y: 16 * u))
        p.addQuadCurve(to: CGPoint(x: 17 * u, y: 12.5 * u), control: CGPoint(x: 15 * u, y: 11 * u))
        p.addQuadCurve(to: CGPoint(x: 20 * u, y: 16 * u),   control: CGPoint(x: 19 * u, y: 14 * u))
        return p
    }
}

private struct SignatureBaselineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 3 * u, y: 19.5 * u))
        p.addLine(to: CGPoint(x: 21 * u, y: 19.5 * u))
        return p
    }
}

private struct SignatureDotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.addEllipse(in: CGRect(x: (18.5 - 0.9) * u, y: (12 - 0.9) * u, width: 1.8 * u, height: 1.8 * u))
        return p
    }
}

private struct SmallCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 9 * u, y: 11.5 * u))
        p.addLine(to: CGPoint(x: 11 * u, y: 13.5 * u))
        p.addLine(to: CGPoint(x: 15 * u, y: 9.5 * u))
        return p
    }
}

private struct EligibilityCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 8 * u, y: 12.5 * u))
        p.addLine(to: CGPoint(x: 11 * u, y: 15 * u))
        p.addLine(to: CGPoint(x: 16 * u, y: 9.5 * u))
        return p
    }
}

private struct PillCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.move(to: CGPoint(x: 5 * u, y: 12.5 * u))
        p.addLine(to: CGPoint(x: 10 * u, y: 17 * u))
        p.addLine(to: CGPoint(x: 19 * u, y: 7.5 * u))
        return p
    }
}

private struct ChevronRightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 9 * u, y: 6 * u))
        p.addLine(to: CGPoint(x: 15 * u, y: 12 * u))
        p.addLine(to: CGPoint(x: 9 * u, y: 18 * u))
        return p
    }
}

private struct ChevronLeftShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = s(rect)
        var p = Path()
        p.move(to: CGPoint(x: 15 * u, y: 6 * u))
        p.addLine(to: CGPoint(x: 9 * u, y: 12 * u))
        p.addLine(to: CGPoint(x: 15 * u, y: 18 * u))
        return p
    }
}

// MARK: - Preview

#Preview("Illustration gallery") {
    ZStack {
        Color.movo.background.ignoresSafeArea()
        VStack(spacing: 28) {
            HStack(spacing: 24) {
                ShieldKeyholeIcon()
                HerringShieldIcon()
                DocumentLinesIcon()
                SignatureIcon()
            }
            HStack(spacing: 24) {
                ShieldCheckIcon()
                DocumentBadgeIcon()
                EligibilityCheckIcon()
                ReviewedCheckPill()
                UnreadChevronIcon()
                BackChevronIcon()
            }
            HStack(spacing: 24) {
                ShieldKeyholeIcon(
                    stroke: Color.movo.accent,
                    accent: Color.movo.accent
                )
                DocumentLinesIcon(
                    stroke: Color.movo.accent,
                    accent: Color.movo.accent
                )
            }
        }
    }
}

// MARK: - ChevronDownIcon — used for country code picker, dropdowns

public struct ChevronDownIcon: View {
    public var size: CGFloat = 12
    public var tint: Color = Color.movo.textTertiary
    public var lineWidth: CGFloat = DesignTokens.Stroke.thick

    public init(
        size: CGFloat = 12,
        tint: Color = Color.movo.textTertiary,
        lineWidth: CGFloat = DesignTokens.Stroke.thick
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ChevronDownShape()
            .stroke(tint, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct ChevronDownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.move(to: CGPoint(x: 6 * u, y: 9 * u))
        p.addLine(to: CGPoint(x: 12 * u, y: 15 * u))
        p.addLine(to: CGPoint(x: 18 * u, y: 9 * u))
        return p
    }
}

// MARK: - EnvelopeIcon — message/SMS contexts

public struct EnvelopeIcon: View {
    public var size: CGFloat = 14
    public var tint: Color = Color.movo.textTertiary
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 14,
        tint: Color = Color.movo.textTertiary,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            EnvelopeBodyShape()
                .stroke(tint, style: .init(lineWidth: lineWidth, lineJoin: .round))
            EnvelopeFlapShape()
                .stroke(tint, style: .init(lineWidth: lineWidth, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct EnvelopeBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: 3 * u, y: 6 * u, width: 18 * u, height: 14 * u),
            cornerSize: CGSize(width: 2 * u, height: 2 * u)
        )
        return p
    }
}

private struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.move(to: CGPoint(x: 3 * u, y: 8 * u))
        p.addLine(to: CGPoint(x: 12 * u, y: 14 * u))
        p.addLine(to: CGPoint(x: 21 * u, y: 8 * u))
        return p
    }
}

// MARK: - PrivacyNoticeIcon — small lined-document for inline trust chips

public struct PrivacyNoticeIcon: View {
    public var size: CGFloat = 16
    public var tint: Color = Color.movo.accent
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 16,
        tint: Color = Color.movo.accent,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            PrivacyNoticeBodyShape()
                .stroke(tint, style: .init(lineWidth: lineWidth, lineJoin: .round))
            PrivacyNoticeLinesShape()
                .stroke(tint, style: .init(lineWidth: lineWidth - 0.3, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct PrivacyNoticeBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: 4 * u, y: 3 * u, width: 14 * u, height: 18 * u),
            cornerSize: CGSize(width: 2 * u, height: 2 * u)
        )
        return p
    }
}

private struct PrivacyNoticeLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.move(to: CGPoint(x: 9 * u, y: 7 * u));  p.addLine(to: CGPoint(x: 13 * u, y: 7 * u))
        p.move(to: CGPoint(x: 9 * u, y: 11 * u)); p.addLine(to: CGPoint(x: 15 * u, y: 11 * u))
        p.move(to: CGPoint(x: 9 * u, y: 15 * u)); p.addLine(to: CGPoint(x: 12 * u, y: 15 * u))
        return p
    }
}

// MARK: - ErrorBadgeIcon — circle-with-exclamation for inline error helpers

public struct ErrorBadgeIcon: View {
    public var size: CGFloat = 14
    public var tint: Color = Color.movo.danger
    public var lineWidth: CGFloat = DesignTokens.Stroke.medium

    public init(
        size: CGFloat = 14,
        tint: Color = Color.movo.danger,
        lineWidth: CGFloat = DesignTokens.Stroke.medium
    ) {
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle().strokeBorder(tint, lineWidth: lineWidth)
            ErrorBangShape()
                .stroke(tint, style: .init(lineWidth: lineWidth + 0.2, lineCap: .round))
            ErrorBangDotShape().fill(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ErrorBangShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.move(to: CGPoint(x: 12 * u, y: 7 * u))
        p.addLine(to: CGPoint(x: 12 * u, y: 13 * u))
        return p
    }
}

private struct ErrorBangDotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 24.0
        var p = Path()
        p.addEllipse(in: CGRect(x: 11 * u, y: 15.5 * u, width: 2 * u, height: 2 * u))
        return p
    }
}



/// Full lockup: monogram + "MOVOCASH" wordmark. Convenience view that
/// wraps `MovoLogoMark` with the tracked wordmark — matches the brand
/// SVG proportions. Pass `vertical: false` for a horizontal lockup.
public struct MovoBrandLockup: View {
    public var markSize: CGFloat = 120
    public var wordmarkSize: CGFloat = 28
    public var spacing: CGFloat = 28
    public var color: Color = MovoLogoMark.brandSilver
    public var vertical: Bool = true

    public init(
        markSize: CGFloat = 120,
        wordmarkSize: CGFloat = 28,
        spacing: CGFloat = 28,
        color: Color = MovoLogoMark.brandSilver,
        vertical: Bool = true
    ) {
        self.markSize = markSize
        self.wordmarkSize = wordmarkSize
        self.spacing = spacing
        self.color = color
        self.vertical = vertical
    }

    public var body: some View {
        let layout: AnyLayout = vertical
                ? AnyLayout(VStackLayout(spacing: spacing))
                : AnyLayout(HStackLayout(spacing: spacing))
        layout {
            MovoLogoMark(size: markSize, color: color)
            Text("MOVOCASH")
                .font(.system(size: wordmarkSize, weight: .regular))
                .tracking(8)
                .foregroundStyle(color)
                .padding(.leading, 8) // visually compensate for trailing tracking
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MovoCash")
    }
}

// MARK: - Brand mark
//  =====================================================================
//  MovoCash MV monogram. Authored on a 90×90 grid (matches the brand
//  SVG). Use anywhere the logo appears: splash, nav bar, empty states,
//  about page. The default color is the brand silver `#D9D9D9` — an
//  explicit brand hex, intentionally NOT one of the palette tokens, so
//  the mark reads as itself across both dark and light themes.


public struct MovoLogoMark: View {
    public var size: CGFloat = 90
    public var color: Color = MovoLogoMark.brandSilver

    /// MovoCash brand silver — #D9D9D9. Used for the monogram and wordmark.
    public static let brandSilver = Color(red: 0.851, green: 0.851, blue: 0.851)

    public init(size: CGFloat = 90, color: Color = MovoLogoMark.brandSilver) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        ZStack {
            MovoMarkTopStrokeShape().fill(color)
            MovoMarkMiddleStrokeShape().fill(color)
            MovoMarkLeftLegShape().fill(color)
            MovoMarkRightLegShape().fill(color)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("MovoCash")
    }
}

private func mvScale(_ rect: CGRect) -> CGFloat { rect.width / 90.0 }

/// Top V — "0,0 18,0 45,24 72,0 90,0 45,42"
private struct MovoMarkTopStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = mvScale(rect)
        var p = Path()
        p.move(to: CGPoint(x: 0,        y: 0))
        p.addLine(to: CGPoint(x: 18 * u, y: 0))
        p.addLine(to: CGPoint(x: 45 * u, y: 24 * u))
        p.addLine(to: CGPoint(x: 72 * u, y: 0))
        p.addLine(to: CGPoint(x: 90 * u, y: 0))
        p.addLine(to: CGPoint(x: 45 * u, y: 42 * u))
        p.closeSubpath()
        return p
    }
}

/// Middle V — "0,34 18,34 45,58 72,34 90,34 45,76"
private struct MovoMarkMiddleStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = mvScale(rect)
        var p = Path()
        p.move(to: CGPoint(x: 0,        y: 34 * u))
        p.addLine(to: CGPoint(x: 18 * u, y: 34 * u))
        p.addLine(to: CGPoint(x: 45 * u, y: 58 * u))
        p.addLine(to: CGPoint(x: 72 * u, y: 34 * u))
        p.addLine(to: CGPoint(x: 90 * u, y: 34 * u))
        p.addLine(to: CGPoint(x: 45 * u, y: 76 * u))
        p.closeSubpath()
        return p
    }
}

/// Left leg — "0,0 14,0 14,76 0,90"
private struct MovoMarkLeftLegShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = mvScale(rect)
        var p = Path()
        p.move(to: CGPoint(x: 0,        y: 0))
        p.addLine(to: CGPoint(x: 14 * u, y: 0))
        p.addLine(to: CGPoint(x: 14 * u, y: 76 * u))
        p.addLine(to: CGPoint(x: 0,      y: 90 * u))
        p.closeSubpath()
        return p
    }
}

/// Right leg — "76,0 90,0 90,90 76,76"
private struct MovoMarkRightLegShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = mvScale(rect)
        var p = Path()
        p.move(to: CGPoint(x: 76 * u, y: 0))
        p.addLine(to: CGPoint(x: 90 * u, y: 0))
        p.addLine(to: CGPoint(x: 90 * u, y: 90 * u))
        p.addLine(to: CGPoint(x: 76 * u, y: 76 * u))
        p.closeSubpath()
        return p
    }
}
