//
//  Theme.swift
//  MovoCash
//
//  Semantic color API. Views call `MovoTheme.color.background` (intent),
//  not `DesignTokens.Palette.background` (raw token).
//
//  v2.0 — Single ADAPTIVE scheme. `voidSilver` automatically renders the
//  correct hex based on system appearance or any `.preferredColorScheme(...)`
//  override. No more global theme swapping needed for light/dark.
//
//  This indirection still lets us:
//  - Re-skin the app by swapping palette tokens without touching views
//  - Add new semantic intents (e.g., `cardElevated`) without rewriting palette
//  - Eventually support multiple themes (e.g., High Contrast) by swapping
//    `MovoTheme.color` for a different MovoColorScheme variant
//

import SwiftUI

// MARK: - Theme entry point

public enum MovoTheme {
    /// Active palette. Single source of truth for color intent → palette.
    /// Defaults to `voidSilver` (adaptive light/dark).
    public static var color: MovoColorScheme = .voidSilver
}

// MARK: - Semantic color scheme

public struct MovoColorScheme: Sendable {
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

    // On-accent label color — high-contrast text drawn on accent fills
    public let onAccent:        ColorToken

    // Card surface — adaptive elevation: light = platinum lift, dark = elevated lift
    public let cardSurface:     ColorToken
    // Card border — brighter than borderStrong for visible outlines on cardSurface in dark mode
    public let cardBorder:      ColorToken
    // Ghost surface — surface at 85% opacity, subtle near-flush card feel
   // public let ghostSurface:    ColorToken

    // Silver sheen / watermark — adaptive.
    public let silverTint:         ColorToken

    // Card tile face — locked near-black for the Void Silver card cell in the dashboard carousel.
    public let cardVoid:           ColorToken

    // Card artwork — brand-locked (heritage black card; same hex in both modes)
    // Scoped to the physical card artwork view only.
    public let cardArtwork:        ColorToken
    public let onCardArtwork:      ColorToken
    public let cardArtworkMuted:   ColorToken
    public let cardArtworkBorder:  ColorToken

    // Balloon illustration pigments — locked, non-adaptive.
    // Scoped to RegistrationCelebrationHero only. Not for text or interactive use.
    public let balloonHighlight:   ColorToken
    public let balloonShade:       ColorToken

    // MARK: - Built-in scheme: Void Silver (adaptive)

    public static let voidSilver = MovoColorScheme(
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

        // Borders: slightly darker than the canvas in both modes.
        // Light: elevated = #D0D3DC, borderStrong = #BFC3CE
        // Dark:  elevated = #1C1C25, borderStrong = #2A2A35
        border:        DesignTokens.Palette.elevated,
        borderStrong:  DesignTokens.Palette.elevatedHigh,

        success:       DesignTokens.Palette.success,
        successTint:   DesignTokens.Palette.success.opacity(0.12),
        danger:        DesignTokens.Palette.danger,
        dangerTint:    DesignTokens.Palette.danger.opacity(0.10),
        warning:       DesignTokens.Palette.warning,

        // Always near-black — works on the green accent in BOTH modes.
        // (Was previously `background`, which would have flipped to white
        //  in light mode and made CTA labels invisible.)
        onAccent:      DesignTokens.Palette.onAccent,
        cardSurface:   DesignTokens.Palette.cardSurface,
        cardBorder:    DesignTokens.Palette.cardBorder,

        silverTint:        DesignTokens.Palette.silverTint,

        cardVoid:          DesignTokens.Palette.cardVoid,

        // Heritage black card — locked, never adapts.
        cardArtwork:       DesignTokens.Palette.cardArtwork,
        onCardArtwork:     DesignTokens.Palette.onCardArtwork,
        cardArtworkMuted:  DesignTokens.Palette.cardArtworkMuted,
        cardArtworkBorder: DesignTokens.Palette.cardArtworkBorder,

        // Balloon illustration pigments — locked.
        balloonHighlight:  DesignTokens.Palette.balloonHighlight,
        balloonShade:      DesignTokens.Palette.balloonShade
    )
}

