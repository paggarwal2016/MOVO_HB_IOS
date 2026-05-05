//
//  Theme.swift
//  MovoCash
//
//  Semantic color API. Views call `Theme.color.background` (intent),
//  not `DesignTokens.Palette.background` (raw token).
//
//  This indirection lets us:
//  - Re-skin the app by swapping palette tokens without touching views
//  - Add new semantic intents (e.g., `cardElevated`) without rewriting palette
//  - Eventually support multiple themes (e.g., Light, High Contrast)
//

import SwiftUI

// MARK: - Theme entry point

public enum MovoTheme {
    /// Active palette. Single source of truth for color intent → palette.
    public static var color: ColorScheme = .voidSilver
}

// MARK: - Semantic color scheme

public struct ColorScheme: Sendable {
    // Surfaces
    public let background:      ColorToken   // App canvas
    public let surface:         ColorToken   // Default card / row background
    public let elevated:        ColorToken   // Raised card (modals, hero panels)
    public let elevatedHigh:    ColorToken   // Highest elevation (key cards, primary card)

    // Accent
    public let accent:          ColorToken   // Primary brand accent
    public let accentTint:      ColorToken   // Accent backgrounds (badges, hover)
    public let accentBorder:    ColorToken   // Accent strokes / focus rings
    public let accentSoft:      ColorToken   // Accent halos / glow shadows

    // Text
    public let textPrimary:     ColorToken   // Headlines, primary numbers
    public let textSecondary:   ColorToken   // Body copy
    public let textTertiary:    ColorToken   // Captions, eyebrow labels
    public let textDisabled:    ColorToken   // Placeholder, inactive

    // Borders & separators
    public let border:          ColorToken   // Hairline borders, dividers
    public let borderStrong:    ColorToken   // More visible borders

    // Status (semantic)
    public let success:         ColorToken
    public let successTint:     ColorToken
    public let danger:          ColorToken
    public let dangerTint:      ColorToken
    public let warning:         ColorToken

    // On-accent text (high-contrast text drawn on accent fills)
    public let onAccent:        ColorToken

    // MARK: - Built-in scheme: Void Silver

    public static let voidSilver = ColorScheme(
        background:    DesignTokens.Palette.background,
        surface:       DesignTokens.Palette.surface,
        elevated:      DesignTokens.Palette.elevated,
        elevatedHigh:  DesignTokens.Palette.elevatedHigh,

        accent:        DesignTokens.Palette.accent,
        accentTint:    DesignTokens.Palette.accent.opacity(0.12),
        accentBorder:  DesignTokens.Palette.accent.opacity(0.40),
        accentSoft:    DesignTokens.Palette.accent.opacity(0.06),

        textPrimary:   DesignTokens.Palette.textPrimary,
        textSecondary: DesignTokens.Palette.textSecondary,
        textTertiary:  DesignTokens.Palette.textTertiary,
        textDisabled:  DesignTokens.Palette.textDisabled,

        border:        DesignTokens.Palette.elevated,
        borderStrong:  DesignTokens.Palette.elevatedHigh,

        success:       DesignTokens.Palette.success,
        successTint:   DesignTokens.Palette.success.opacity(0.12),
        danger:        DesignTokens.Palette.danger,
        dangerTint:    DesignTokens.Palette.danger.opacity(0.10),
        warning:       DesignTokens.Palette.warning,

        onAccent:      DesignTokens.Palette.background  // Black-on-green = high contrast
    )
}
