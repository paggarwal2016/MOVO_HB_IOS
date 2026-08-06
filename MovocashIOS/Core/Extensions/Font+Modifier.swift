//
//  Font+Modifier.swift
//  MovocashIOS
//
//  Single application point for Movo typography.
//
//  .movoFont(_ style: AppTextStyle) is the only way to apply a Movo font token.
//  It handles:
//    1. Dynamic Type  — every Montserrat token scales via Font.custom(_, size:, relativeTo:)
//    2. Bold Text     — reads legibilityWeight and steps up one rung on the ladder:
//                       Regular → Medium → SemiBold → Bold
//
//  System-font tokens (activityAmount, cardNumber) bypass the ladder; SF responds
//  to Bold Text natively.
//
//  NOTE: the Regular→Medium rung depends on Phase 0 (Montserrat-Medium.ttf bundled).
//  Until that file is registered, those tokens will fall back to system font.
//
//  Sizes: all Montserrat cases reference AppFont size constants (AppFont.bodySize,
//  AppFont.captionSize, etc.) — do not hardcode literals here. Change AppFont.scale
//  to proportionally rescale the whole app.
//

import SwiftUI

// MARK: - MovoFontModifier

struct MovoFontModifier: ViewModifier {

    let style: AppTextStyle
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content.font(resolvedFont)
    }

    // MARK: - Font resolution

    private var resolvedFont: Font {
        switch style {

        // ── System fonts ──────────────────────────────────────────────────────────
        // Text-style form ensures Dynamic Type scaling. SF handles Bold Text natively.

        case .activityAmount:
            return .system(.callout, weight: .medium)

        case .cardNumber:
            return .system(.footnote, design: .monospaced)

        // ── Montserrat tokens ─────────────────────────────────────────────────────
        // Face is resolved via the Bold Text ladder before the font is constructed.
        // Sizes reference AppFont constants — single source of truth in AppFont.scale.

        case .labelCaps:
            return .custom(resolvedFace, size: AppFont.labelCapsSize, relativeTo: .caption2)
        case .balance:
            return .custom(resolvedFace, size: AppFont.balanceSize,   relativeTo: .largeTitle)
        case .hero:
            return .custom(resolvedFace, size: AppFont.heroSize,      relativeTo: .title2)
        case .body:
            return .custom(resolvedFace, size: AppFont.bodySize,      relativeTo: .body)
        case .caption:
            return .custom(resolvedFace, size: AppFont.captionSize,   relativeTo: .footnote)
        case .cta:
            return .custom(resolvedFace, size: AppFont.ctaSize,       relativeTo: .callout)
        case .rowTitle:
            return .custom(resolvedFace, size: AppFont.bodySize,      relativeTo: .callout)
        case .rowValue:
            return .custom(resolvedFace, size: AppFont.bodySize,      relativeTo: .callout)
        }
    }

    // MARK: - Bold Text ladder  (Regular → Medium → SemiBold → Bold)

    private var resolvedFace: String {
        guard legibilityWeight == .bold else { return baseFace }
        switch baseFace {
        case Montserrat.regular:  return Montserrat.medium
        case Montserrat.medium:   return Montserrat.semibold
        case Montserrat.semibold: return Montserrat.bold
        default:                  return baseFace
        }
    }

    private var baseFace: String {
        switch style {
        case .body, .caption:
            return Montserrat.regular
        case .rowTitle:
            return Montserrat.medium
        case .hero, .balance, .cta, .rowValue, .labelCaps:
            return Montserrat.semibold
        case .activityAmount, .cardNumber:
            return Montserrat.regular   // unreachable; system tokens handled above
        }
    }

    // MARK: - PostScript name constants

    private enum Montserrat {
        static let regular  = "Montserrat-Regular"
        static let medium   = "Montserrat-Medium"   // Phase 0: requires Montserrat-Medium.ttf bundled
        static let semibold = "Montserrat-SemiBold"
        static let bold     = "Montserrat-Bold"
    }
}

// MARK: - View extension

extension View {
    /// Apply a Movo typography token.
    /// Handles Dynamic Type scaling and Bold Text face-swap automatically.
    func movoFont(_ style: AppTextStyle) -> some View {
        modifier(MovoFontModifier(style: style))
    }
}
