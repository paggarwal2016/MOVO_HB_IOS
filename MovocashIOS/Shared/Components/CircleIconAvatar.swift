//
//  CircleIconAvatar.swift
//  MovocashIOS
//

import SwiftUI

/// Reusable circular icon avatar for add / action affordances.
///
/// Usage:
/// ```swift
/// CircleIconAvatar(systemName: "plus", size: 44, tint: .accent)
/// CircleIconAvatar(systemName: "building.columns", size: 38, tint: .neutral)
/// ```
enum CircleIconAvatarTint {
    /// Accent-tinted: `accentTint` fill · `accentBorder` stroke · `accent` icon.
    case accent
    /// Neutral: `surface` fill · `borderStrong` stroke · `textPrimary` icon.
    case neutral
}

struct CircleIconAvatar: View {

    let systemName: String
    var size: CGFloat = 44
    var tint: CircleIconAvatarTint = .accent

    private var fillColor: Color {
        switch tint {
        case .accent:  return Color.movo.accentTint
        case .neutral: return Color.movo.surface
        }
    }

    private var strokeColor: Color {
        switch tint {
        case .accent:  return Color.movo.accentBorder
        case .neutral: return Color.movo.borderStrong
        }
    }

    private var iconColor: Color {
        switch tint {
        case .accent:  return Color.movo.accent
        case .neutral: return Color.movo.textPrimary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .overlay(Circle().strokeBorder(strokeColor, lineWidth: Stroke.hairline))
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .frame(width: size, height: size)
    }
}
