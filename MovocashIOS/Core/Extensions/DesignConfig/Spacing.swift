//
//  Spacing.swift
//  MovoCash
//
//  Semantic spacing & radius API.
//  Built on a 4-pt grid. Use semantic names (Spacing.cardPadding) over magic numbers.
//

import SwiftUI

public enum Spacing {

    // ─────────────────────────────────────────────────────────────
    // RAW SCALE (4-pt grid)
    // ─────────────────────────────────────────────────────────────
    public static let xxs:  CGFloat = DesignTokens.Spacing.xxs    // 2
    public static let xs:   CGFloat = DesignTokens.Spacing.xs     // 4
    public static let sm:   CGFloat = DesignTokens.Spacing.sm     // 8
    public static let md:   CGFloat = DesignTokens.Spacing.md     // 12
    public static let lg:   CGFloat = DesignTokens.Spacing.lg     // 16
    public static let xl:   CGFloat = DesignTokens.Spacing.xl     // 20
    public static let xxl:  CGFloat = DesignTokens.Spacing.xxl    // 24
    public static let xxxl: CGFloat = DesignTokens.Spacing.xxxl   // 32
    public static let huge: CGFloat = DesignTokens.Spacing.huge   // 40

    // ─────────────────────────────────────────────────────────────
    // SEMANTIC (preferred — gives meaning to numbers)
    // ─────────────────────────────────────────────────────────────

    /// Standard horizontal screen padding (16pt edges)
    public static let screenHorizontal: CGFloat = lg

    /// Vertical padding between major sections
    public static let sectionGap: CGFloat = lg

    /// Padding inside cards/heroes (16pt all sides)
    public static let cardPadding: CGFloat = lg

    /// Padding inside compact list rows (vertical)
    public static let rowPaddingVertical: CGFloat = md

    /// Spacing between stacked rows in a card
    public static let rowGap: CGFloat = sm

    /// Gap between tabs / quick-action buttons
    public static let buttonGap: CGFloat = sm - 2  // 6pt

    /// Padding around CTA buttons
    public static let buttonPaddingVertical: CGFloat = md
    public static let buttonPaddingHorizontal: CGFloat = lg
}

// MARK: - Corner radius (semantic)

public enum Radius {
    public static let xs:    CGFloat = DesignTokens.Radius.xs     // 6
    public static let sm:    CGFloat = DesignTokens.Radius.sm     // 8
    public static let md:    CGFloat = DesignTokens.Radius.md     // 10  — buttons (inputs, CTAs)
    public static let lg:    CGFloat = DesignTokens.Radius.lg     // 12  — list cards
    public static let xl:    CGFloat = DesignTokens.Radius.xl     // 14  — hero cards
    public static let xxl:   CGFloat = DesignTokens.Radius.xxl    // 16  — full-bleed hero, sheets
    public static let pill:  CGFloat = DesignTokens.Radius.pill   // pill / fully round

    // SEMANTIC
    public static let button:        CGFloat = md       // 10
    public static let card:          CGFloat = lg       // 12
    public static let heroCard:      CGFloat = xl       // 14
    public static let sheet:         CGFloat = 22       // bottom sheet top corners
    public static let largeButton:   CGFloat = pill     // primary CTAs (Transfer/Confirm)
}

// MARK: - Stroke widths

public enum Stroke {
    public static let hairline: CGFloat = DesignTokens.Stroke.hairline   // 0.5 — borders
    public static let thin:     CGFloat = DesignTokens.Stroke.thin       // 1.0 — emphasis borders
    public static let medium:   CGFloat = DesignTokens.Stroke.medium     // 1.5 — focused / active
    public static let thick:    CGFloat = DesignTokens.Stroke.thick      // 2.0 — checkmarks, icons
}
