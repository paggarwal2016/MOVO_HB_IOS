//
//  DesignTokens.swift
//  MovoCash
//
//  Single source of truth for the Void Silver brand system.
//  Pure data — no view dependencies. Other layers (Theme, Typography, Spacing)
//  read from these constants so the entire app re-skins from one place.
//
//  v2.0 — ADAPTIVE. Every ColorToken carries both light and dark hex values.
//  SwiftUI views automatically follow system appearance or any explicit
//  `.preferredColorScheme(...)` override. Existing call sites unchanged.
//
//  Light palette: "Void Silver — App Store Edition" (platinum / inverted spectrum)
//  Dark  palette: "Void Silver" (near-black + silver + Amex Heritage Green)
//
//  Created by the Movo iOS team. Update palette here only after sign-off from G+.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// All raw design tokens for the Void Silver brand system.
/// Access through `MovoTheme` / `MovoTypography` / `MovoSpacing` extensions
/// rather than calling these constants directly from views.
public enum DesignTokens {

    // MARK: - Brand identity

    public enum Brand {
        public static let name      = "Movo"
        public static let palette   = "Void Silver"
        public static let version   = "2.0.0"   // bumped — adaptive light/dark
    }

    // MARK: - Color palette (Void Silver — adaptive)
    //
    // Naming convention: pairs of (light, dark) hex literals per token.
    // Light values come from the App Store Edition (inverted spectrum).
    // Dark values come from the original Void Silver palette.

    public enum Palette {

        // Surfaces (background → most elevated)
        public static let background = ColorToken(
            light: 0xF2F3F6, dark: 0x060608, name: "background")

        public static let surface = ColorToken(
            light: 0xE4E6EC, dark: 0x0F0F14, name: "surface")

        public static let elevated = ColorToken(
            light: 0xD0D3DC, dark: 0x1C1C25, name: "elevated")

        public static let elevatedHigh = ColorToken(
            light: 0xBFC3CE, dark: 0x2A2A35, name: "elevatedHigh")

        // Accent — Amex Heritage Green (LOCKED across modes)
        public static let accent = ColorToken(
            light: 0x629F86, dark: 0x629F86, name: "accent")

        // Text (most → least emphasis)
        public static let textPrimary = ColorToken(
            light: 0x0A0A0E, dark: 0xF2F3F6, name: "textPrimary")     // Headlines

        public static let textSecondary = ColorToken(
            light: 0x1A1A22, dark: 0xD4D7E0, name: "textSecondary")   // Primary body

        public static let textTertiary = ColorToken(
            light: 0x3A3A44, dark: 0xA8ACBA, name: "textTertiary")    // Captions / meta

        public static let textDisabled = ColorToken(
            light: 0x8A8E9A, dark: 0x6E7480, name: "textDisabled")

        // Status (semantic)
        public static let success = ColorToken(
            light: 0x629F86, dark: 0x629F86, name: "success")          // alias for accent

        public static let danger = ColorToken(
            light: 0xB85450, dark: 0xB85450, name: "danger")

        public static let warning = ColorToken(
            light: 0xB08840, dark: 0xC8A45F, name: "warning")          // darker gold in light

        // On-accent label color — light: platinum white on green (brand spec); dark: near-black on green.
        public static let onAccent = ColorToken(
            light: 0xF2F3F6, dark: 0x060608, name: "onAccent")

        // Card surface — adaptive elevation tuned per mode. 1C1C25
        // Light: subtle platinum lift (matches surface). Dark: clear lift from black (matches elevated).
        public static let cardSurface = ColorToken(
            light: 0xE4E6EC, dark: 0x0F0F14, name: "cardSurface", alpha: 0.85)

        // Card border — paired with cardSurface for visible outlines in dark mode.
        // Light: same as borderStrong light. Dark: ~70-unit lift above cardSurface for hairline visibility.
        public static let cardBorder = ColorToken(
            light: 0xBFC3CE, dark: 0x1C1C25, name: "cardBorder")

        

        // Card tile face — LOCKED near-black surface (~#101315) for the Void Silver card cell.
        // Sits between background (0x060608) and surface (0x0F0F14). Locked across modes
        // because the card tile always presents as a dark branded surface.
        public static let cardVoid = ColorToken(light: 0xD0D3DC, dark: 0x101315, name: "cardVoid")

        // Void Silver card gradient stops — ADAPTIVE.
        // Dark:  deep void black (branded dark card).
        // Light: cool platinum (branded light / App Store Edition card).
        public static let cardVoidTop    = ColorToken(light: 0xD8DBE2, dark: 0x16191D, name: "cardVoidTop")
        public static let cardVoidMid    = ColorToken(light: 0xCDD0D8, dark: 0x0A0C0E, name: "cardVoidMid")
        public static let cardVoidBottom = ColorToken(light: 0xD2D5DC, dark: 0x0E1114, name: "cardVoidBottom")

        // Silver — sheen, hairline, watermark. ADAPTIVE: darker in light mode for contrast.
        public static let silverTint     = ColorToken(light: 0x5A6070, dark: 0xA8B2C0, name: "silverTint")

        // Card artwork — LOCKED (heritage Amex-style black card; constant across both modes).
        // Use ONLY in the physical card artwork view. Do not use for any other UI surface.
        public static let cardArtwork       = ColorToken(hex: 0x060608, name: "cardArtwork")
        public static let onCardArtwork     = ColorToken(hex: 0xF2F3F6, name: "onCardArtwork")
        public static let cardArtworkMuted  = ColorToken(hex: 0xA8ACBA, name: "cardArtworkMuted")
        public static let cardArtworkBorder = ColorToken(hex: 0x1C1C25, name: "cardArtworkBorder")

        // Movo label system
        // Type badge — neutral silver, no green. Border-only container.
        public static let typeBadgeText   = ColorToken(light: 0x6A727C, dark: 0x9AA2AC, name: "typeBadgeText")
        public static let typeBadgeBorder = ColorToken(light: 0x000000, dark: 0xA8B2C0, name: "typeBadgeBorder", alpha: 0.22)

        // Action button — elevated secondary surface.
        // Light: tonal green fill/border. Dark: slate fill + greenLight text. Dark values unchanged.
        public static let actionFill   = ColorToken(light: 0x629F86, dark: 0x242A31, name: "actionFill",   lightAlpha: 0.20, darkAlpha: 1.00)
        public static let actionBorder = ColorToken(light: 0x4E8870, dark: 0xFFFFFF, name: "actionBorder", lightAlpha: 0.50, darkAlpha: 0.09)
        public static let actionText   = ColorToken(light: 0x3E7560, dark: 0x7BB8A0, name: "actionText")
    }

    // MARK: - Spacing scale (4-pt grid)

    public enum Spacing {
        public static let xxs:  CGFloat = 2
        public static let xs:   CGFloat = 4
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 16
        public static let xl:   CGFloat = 20
        public static let xxl:  CGFloat = 24
        public static let xxxl: CGFloat = 32
        public static let huge: CGFloat = 40
    }

    // MARK: - Corner radius

    public enum Radius {
        public static let xs:    CGFloat = 6
        public static let sm:    CGFloat = 8
        public static let md:    CGFloat = 10
        public static let lg:    CGFloat = 12
        public static let xl:    CGFloat = 14
        public static let xxl:   CGFloat = 16
        public static let pill:  CGFloat = 999
    }

    // MARK: - Stroke widths

    public enum Stroke {
        public static let hairline: CGFloat = 0.5
        public static let thin:     CGFloat = 1.0
        public static let medium:   CGFloat = 1.5
        public static let thick:    CGFloat = 2.0
    }

    // MARK: - Animation

    public enum Motion {
        public static let fast:     Double = 0.15
        public static let standard: Double = 0.25
        public static let slow:     Double = 0.40
    }
}

// MARK: - Color token type

/// A named color token. Holds both `lightHex` and `darkHex` and resolves
/// to the right value at render time via `UIColor(dynamicProvider:)`.
///
/// Exposes both `Color` (SwiftUI) and `UIColor` (UIKit interop) so the
/// same token works in both worlds and stays adaptive across them.
public struct ColorToken: Sendable {
    public let lightHex: UInt32
    public let darkHex: UInt32
    public let name: String
    /// Uniform alpha — kept for backward compatibility. Equal to `darkAlpha` for per-mode tokens.
    public let alpha: Double
    /// Per-mode alpha resolved in light appearance.
    public let lightAlpha: Double
    /// Per-mode alpha resolved in dark appearance.
    public let darkAlpha: Double

    /// Adaptive token — separate hex for light and dark, same alpha in both.
    public init(light: UInt32, dark: UInt32, name: String, alpha: Double = 1.0) {
        self.lightHex = light; self.darkHex = dark; self.name = name
        self.alpha = alpha; self.lightAlpha = alpha; self.darkAlpha = alpha
    }

    /// Static token — same hex in both modes (e.g. brand accent).
    public init(hex: UInt32, name: String, alpha: Double = 1.0) {
        self.lightHex = hex; self.darkHex = hex; self.name = name
        self.alpha = alpha; self.lightAlpha = alpha; self.darkAlpha = alpha
    }

    /// Adaptive token with independent alpha per appearance.
    /// `alpha` mirrors `darkAlpha` for any code that reads it directly.
    public init(light: UInt32, dark: UInt32, name: String, lightAlpha: Double, darkAlpha: Double) {
        self.lightHex = light; self.darkHex = dark; self.name = name
        self.lightAlpha = lightAlpha; self.darkAlpha = darkAlpha
        self.alpha = darkAlpha
    }

    /// Returns a copy of this token with a uniform adjusted alpha.
    public func opacity(_ alpha: Double) -> ColorToken {
        ColorToken(light: lightHex, dark: darkHex, name: name, alpha: alpha)
    }

    /// SwiftUI `Color` value. Tracks system appearance and any
    /// `.preferredColorScheme(...)` override applied upstream.
    public var color: Color {
        #if canImport(UIKit)
        return Color(uiColor: uiColor)
        #else
        return Self.staticColor(hex: darkHex, alpha: darkAlpha)
        #endif
    }

    #if canImport(UIKit)
    /// UIKit `UIColor` value (for legacy bridges, nav bars, status bar tints).
    /// Resolves via `UIColor(dynamicProvider:)` so it tracks trait collection
    /// changes automatically.
    public var uiColor: UIColor {
        let light = lightHex; let dark = darkHex
        let lA = lightAlpha; let dA = darkAlpha
        return UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            let hex = isDark ? dark : light
            let a   = isDark ? dA   : lA
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >>  8) & 0xFF) / 255.0
            let b = CGFloat( hex        & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: CGFloat(a))
        }
    }
    #endif

    /// Resolve to a specific concrete `Color` for a given scheme.
    public func color(for scheme: SwiftUI.ColorScheme) -> Color {
        let hex = scheme == .dark ? darkHex : lightHex
        let a   = scheme == .dark ? darkAlpha : lightAlpha
        return Self.staticColor(hex: hex, alpha: a)
    }

    private static func staticColor(hex: UInt32, alpha: Double) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

