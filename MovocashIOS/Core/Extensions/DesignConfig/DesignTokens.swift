//
//  DesignTokens.swift
//  MovoCash
//
//  Single source of truth for the Void Silver brand system.
//  Pure data — no view dependencies. Other layers (Theme, Typography, Spacing)
//  read from these constants so the entire app re-skins from one place.
//
//  Created by the Movo iOS team. Update palette here only after sign-off from G+.
//

import Foundation
import SwiftUI

/// All raw design tokens for the Void Silver brand system.
/// Access through `MovoTheme` / `MovoTypography` / `MovoSpacing` extensions
/// rather than calling these constants directly from views.
public enum DesignTokens {

    // MARK: - Brand identity

    public enum Brand {
        public static let name      = "Movo"
        public static let palette   = "Void Silver"
        public static let version   = "1.0.0"
    }

    // MARK: - Color palette (Void Silver)

    public enum Palette {
        // Backgrounds (dark → light surfaces)
        public static let background      = ColorToken(hex: 0x060608, name: "background")
        public static let surface         = ColorToken(hex: 0x0F0F14, name: "surface")
        public static let elevated        = ColorToken(hex: 0x1C1C25, name: "elevated")
        public static let elevatedHigh    = ColorToken(hex: 0x2A2A35, name: "elevatedHigh")

        // Accent — Amex Heritage Green
        public static let accent          = ColorToken(hex: 0x629F86, name: "accent")

        // Text (bright → dim)
        public static let textPrimary     = ColorToken(hex: 0xF2F3F6, name: "textPrimary")
        public static let textSecondary   = ColorToken(hex: 0xD4D7E0, name: "textSecondary")
        public static let textTertiary    = ColorToken(hex: 0xA8ACBA, name: "textTertiary")
        public static let textDisabled    = ColorToken(hex: 0x6E7480, name: "textDisabled")

        // Status (semantic)
        public static let success         = ColorToken(hex: 0x629F86, name: "success")  // alias for accent
        public static let danger          = ColorToken(hex: 0xB85450, name: "danger")
        public static let warning         = ColorToken(hex: 0xC8A45F, name: "warning")
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

/// A named color token. Exposes both `Color` (SwiftUI) and `UIColor` (UIKit interop)
/// from a single hex literal so the same token works everywhere.
public struct ColorToken: Sendable {
    public let hex: UInt32
    public let name: String
    public let alpha: Double

    public init(hex: UInt32, name: String, alpha: Double = 1.0) {
        self.hex = hex
        self.name = name
        self.alpha = alpha
    }

    /// Returns a copy of this token with adjusted alpha.
    public func opacity(_ alpha: Double) -> ColorToken {
        ColorToken(hex: hex, name: name, alpha: alpha)
    }

    /// SwiftUI `Color` value.
    public var color: Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    #if canImport(UIKit)
    /// UIKit `UIColor` value (for legacy bridges, navigation bars, status bar tints, etc.).
    public var uiColor: UIColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >>  8) & 0xFF) / 255.0
        let b = CGFloat( hex        & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
    #endif
}

#if canImport(UIKit)
import UIKit
#endif
