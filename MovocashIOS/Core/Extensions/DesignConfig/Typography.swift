//
//  Typography.swift
//  MovoCash
//
//  Semantic typography scale. Views call `Typography.heroTitle` (intent),
//  not `Font.system(size: 26, weight: .semibold)` (raw).
//
//  Single point of truth for:
//  - Font family (system SF Pro by default — swap once here for custom fonts)
//  - Size scale
//  - Weight scale
//  - Letter-spacing (tracking)
//  - Dynamic Type relativity (so users' accessibility settings still work)
//

import SwiftUI

// MARK: - Font family

public enum FontFamily {
    /// Active font family. Default: SF Pro (system).
    /// To swap to a custom family (e.g., Söhne, Inter):
    /// 1. Add the .otf/.ttf to your bundle and register in Info.plist's UIAppFonts
    /// 2. Set `FontFamily.activeFamily = .custom(name: "Söhne-Regular")`
    public static var active: Family = .system

    public enum Family {
        case system
        case custom(regular: String, medium: String, semibold: String, bold: String)
    }

    static func font(size: CGFloat, weight: Font.Weight, design: Font.Design = .default) -> Font {
        switch active {
        case .system:
            return .system(size: size, weight: weight, design: design)
        case .custom(let regular, let medium, let semibold, let bold):
            let name: String
            switch weight {
            case .regular:                       name = regular
            case .medium:                        name = medium
            case .semibold:                      name = semibold
            case .bold, .heavy, .black:          name = bold
            default:                             name = regular
            }
            return .custom(name, size: size)
        }
    }
}

// MARK: - Typography (semantic scale)

/// Use these styles in views — never call Font.system directly.
public enum Typography {

    // ─────────────────────────────────────────────────────────────
    // DISPLAY — for hero amounts and big numbers
    // ─────────────────────────────────────────────────────────────

    /// 80pt bold tabular — for $X.XX hero on Move Money screens
    public static let displayAmount = TextStyle(
        size: 80, weight: .bold, tracking: -3.2, lineHeight: 1.0,
        usage: "Hero amount entry ($1.00 on Move Money)"
    )

    /// 56pt bold tabular — for success-screen amount
    public static let displayLarge = TextStyle(
        size: 56, weight: .bold, tracking: -1.7, lineHeight: 1.0,
        usage: "Success/confirmation amounts"
    )

    /// 44pt — for in-sheet hero amounts (e.g., confirm sheet)
    public static let displayMedium = TextStyle(
        size: 44, weight: .bold, tracking: -1.3, lineHeight: 1.0,
        usage: "Sheet header amount"
    )

    /// 72pt bold tabular — main integer in the amount-entry field (e.g., "1234" in "$1234.00")
    public static let amountInput = TextStyle(
        size: 72, weight: .bold, tracking: -2.5, lineHeight: 1.0,
        usage: "Amount entry integer (Fund / Transfer / Pay screens)"
    )

    /// 32pt semibold — currency prefix \"$\" and cents suffix \".00\" flanking amountInput
    public static let amountPrefix = TextStyle(
        size: 32, weight: .semibold, tracking: -0.8, lineHeight: 1.0,
        usage: "Amount entry currency symbol and decimal cents"
    )

    // ─────────────────────────────────────────────────────────────
    // HEADLINES — for screen titles and section heroes
    // ─────────────────────────────────────────────────────────────

    /// 28pt — Available balance amount on dashboard
    public static let balance = TextStyle(
        size: 28, weight: .semibold, tracking: -0.6,
        usage: "Dashboard balance figure"
    )

    /// 26pt — Hero / success titles
    public static let heroTitle = TextStyle(
        size: 26, weight: .semibold, tracking: -0.5,
        usage: "Hero titles (Transfer sent, etc.)"
    )

    /// 22pt — Page section titles
    public static let sectionTitle = TextStyle(
        size: 22, weight: .semibold, tracking: -0.4,
        usage: "Page-section titles (Send to anyone…)"
    )

    /// 18pt — Card hero titles, sheet titles
    public static let cardHero = TextStyle(
        size: 18, weight: .semibold, tracking: -0.2,
        usage: "Cash card / Pay anyone card titles"
    )

    /// 16pt — Card titles, hero subtitles
    public static let cardTitle = TextStyle(
        size: 16, weight: .semibold, tracking: -0.1,
        usage: "Section / card titles"
    )

    // ─────────────────────────────────────────────────────────────
    // BODY — primary readable copy
    // ─────────────────────────────────────────────────────────────

    /// 14pt — primary body text (account names, list titles)
    public static let body = TextStyle(
        size: 14, weight: .medium,
        usage: "Primary list/row text"
    )

    /// 13pt — secondary body
    public static let bodyCompact = TextStyle(
        size: 13, weight: .medium,
        usage: "Form values, secondary primary"
    )

    /// 13pt regular — body subtitle
    public static let subtitle = TextStyle(
        size: 13, weight: .regular,
        usage: "Subtitles, descriptions"
    )

    // ─────────────────────────────────────────────────────────────
    // SMALL — captions and meta
    // ─────────────────────────────────────────────────────────────

    /// 12pt — descriptions, helper copy
    public static let caption = TextStyle(
        size: 12, weight: .regular,
        usage: "Captions, helper text, meta"
    )

    /// 11pt — small meta, second-line info
    public static let captionSmall = TextStyle(
        size: 11, weight: .regular,
        usage: "Avatar names, labels"
    )

    /// 14pt — eyebrow labels (ALL CAPS, tracked) — e.g., "RECOMMENDED", "WELCOME"
    public static let eyebrow = TextStyle(
        size: 14, weight: .semibold, tracking: 0.8,
        usage: "Eyebrow labels (uppercase + tracked)"
    )

    /// 11pt — status/type pill labels (PRIMARY, VIRTUAL, Movo member, etc.)
    public static let pill = TextStyle(
        size: 11, weight: .semibold, tracking: 0.8,
        usage: "Pill badges — StatusPill, MovoTypeBadge"
    )

    /// 9pt — section labels, smallest readable
    public static let micro = TextStyle(
        size: 9, weight: .medium, tracking: 0.7,
        usage: "Tiny section eyebrow / nav labels"
    )

    // ─────────────────────────────────────────────────────────────
    // BUTTONS — for CTA labels
    // ─────────────────────────────────────────────────────────────

    /// 15pt — primary large CTA (Transfer, Confirm)
    public static let buttonLarge = TextStyle(
        size: 15, weight: .semibold, tracking: 0.3,
        usage: "Primary CTA buttons"
    )

    /// 12pt — secondary / inline CTA (Add Contact, Cancel)
    public static let button = TextStyle(
        size: 12, weight: .semibold, tracking: 0.2,
        usage: "Secondary CTA buttons"
    )

    // ─────────────────────────────────────────────────────────────
    // SPECIALIZED
    // ─────────────────────────────────────────────────────────────

    /// Monospaced reference numbers, card digits, IDs
    public static let mono = TextStyle(
        size: 11, weight: .regular, tracking: 0.6,
        design: .monospaced,
        usage: "Card numbers, transaction refs, IDs"
    )
}

// MARK: - TextStyle

/// One typography style. Encapsulates size, weight, tracking, and
/// applies as a SwiftUI ViewModifier on any `Text` view.
public struct TextStyle: Sendable {
    public let size: CGFloat
    public let weight: Font.Weight
    public let tracking: CGFloat
    public let lineHeight: CGFloat
    public let design: Font.Design
    public let usage: String

    public init(
        size: CGFloat,
        weight: Font.Weight,
        tracking: CGFloat = 0,
        lineHeight: CGFloat = 1.2,
        design: Font.Design = .default,
        usage: String = ""
    ) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.lineHeight = lineHeight
        self.design = design
        self.usage = usage
    }

    /// Resolved SwiftUI Font (respects active font family).
    public var font: Font {
        FontFamily.font(size: size, weight: weight, design: design)
    }
}

// MARK: - Text modifier

/// Apply a `TextStyle` to a `Text` (or any View) with one call.
private struct TypographyModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
    }
}

extension View {
    /// Apply a Typography token: `Text("Hello").textStyle(Typography.heroTitle)`
    public func textStyle(_ style: TextStyle) -> some View {
        modifier(TypographyModifier(style: style))
    }
}
