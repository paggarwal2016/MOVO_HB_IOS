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

        // Card surface — adaptive elevation tuned per mode.
        // Light: subtle platinum lift (matches surface). Dark: clear lift from black (matches elevated).
        public static let cardSurface = ColorToken(
            light: 0xE4E6EC, dark: 0x1C1C25, name: "cardSurface")

        // Card artwork — LOCKED (heritage Amex-style black card; constant across both modes).
        // Use ONLY in the physical card artwork view. Do not use for any other UI surface.
        public static let cardArtwork       = ColorToken(hex: 0x1A1A22, name: "cardArtwork")
        public static let onCardArtwork     = ColorToken(hex: 0xF2F3F6, name: "onCardArtwork")
        public static let cardArtworkMuted  = ColorToken(hex: 0xA8ACBA, name: "cardArtworkMuted")
        public static let cardArtworkBorder = ColorToken(hex: 0x2A2A35, name: "cardArtworkBorder")
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
    public let alpha: Double

    /// Adaptive token — separate hex for light and dark.
    public init(light: UInt32, dark: UInt32, name: String, alpha: Double = 1.0) {
        self.lightHex = light
        self.darkHex = dark
        self.name = name
        self.alpha = alpha
    }

    /// Static token — same hex in both modes (e.g. brand accent).
    public init(hex: UInt32, name: String, alpha: Double = 1.0) {
        self.lightHex = hex
        self.darkHex = hex
        self.name = name
        self.alpha = alpha
    }

    /// Returns a copy of this token with adjusted alpha (preserves adaptiveness).
    public func opacity(_ alpha: Double) -> ColorToken {
        ColorToken(light: lightHex, dark: darkHex, name: name, alpha: alpha)
    }

    /// SwiftUI `Color` value. Tracks system appearance and any
    /// `.preferredColorScheme(...)` override applied upstream.
    public var color: Color {
        #if canImport(UIKit)
        return Color(uiColor: uiColor)
        #else
        return Self.staticColor(hex: darkHex, alpha: alpha)
        #endif
    }

    #if canImport(UIKit)
    /// UIKit `UIColor` value (for legacy bridges, nav bars, status bar tints).
    /// Resolves via `UIColor(dynamicProvider:)` so it tracks trait collection
    /// changes automatically.
    public var uiColor: UIColor {
        let light = lightHex
        let dark  = darkHex
        let a     = alpha
        return UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >>  8) & 0xFF) / 255.0
            let b = CGFloat( hex        & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: CGFloat(a))
        }
    }
    #endif

    /// Resolve to a specific concrete `Color` for a given scheme.
    /// Useful in places where you can't rely on the environment
    /// (e.g. CALayer fills, Core Animation, snapshot rendering).
    public func color(for scheme: SwiftUI.ColorScheme) -> Color {
        let hex = scheme == .dark ? darkHex : lightHex
        return Self.staticColor(hex: hex, alpha: alpha)
    }

    private static func staticColor(hex: UInt32, alpha: Double) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

