//
//  Theme+Modifiers.swift
//  MovoCash
//
//  View modifiers and ergonomic helpers built on top of the design system.
//  These are the "kit" — the things you reach for when building screens.
//

import SwiftUI

// MARK: - Color shortcut on Color

/// Convenience: write `Color.movo.accent` instead of `MovoTheme.color.accent.color`.
extension Color {
    public enum movo {
        public static var background:    Color { MovoTheme.color.background.color }
        public static var surface:       Color { MovoTheme.color.surface.color }
        public static var elevated:      Color { MovoTheme.color.elevated.color }
        public static var elevatedHigh:  Color { MovoTheme.color.elevatedHigh.color }

        public static var accent:        Color { MovoTheme.color.accent.color }
        public static var accentTint:    Color { MovoTheme.color.accentTint.color }
        public static var accentBorder:  Color { MovoTheme.color.accentBorder.color }
        public static var accentSoft:    Color { MovoTheme.color.accentSoft.color }

        public static var textPrimary:   Color { MovoTheme.color.textPrimary.color }
        public static var textSecondary: Color { MovoTheme.color.textSecondary.color }
        public static var textTertiary:  Color { MovoTheme.color.textTertiary.color }
        public static var textDisabled:  Color { MovoTheme.color.textDisabled.color }

        public static var border:        Color { MovoTheme.color.border.color }
        public static var borderStrong:  Color { MovoTheme.color.borderStrong.color }

        public static var success:       Color { MovoTheme.color.success.color }
        public static var successTint:   Color { MovoTheme.color.successTint.color }
        public static var danger:        Color { MovoTheme.color.danger.color }
        public static var dangerTint:    Color { MovoTheme.color.dangerTint.color }
        public static var warning:       Color { MovoTheme.color.warning.color }
        public static var onAccent:      Color { MovoTheme.color.onAccent.color }
    }
}

// MARK: - Card / surface modifiers

/// Standard card surface — used for lists, forms, info groups.
public struct CardSurface: ViewModifier {
    public var padding: CGFloat = Spacing.cardPadding
    public var radius: CGFloat = Radius.card

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.movo.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
            )
    }
}

/// Hero card — for top-level promo/recommendation surfaces with cinematic gradient.
public struct HeroCard: ViewModifier {
    public enum Direction { case topLeft, topRight, center }
    public var gradientFrom: Direction = .topLeft
    public var radius: CGFloat = Radius.heroCard

    private var startPoint: UnitPoint {
        switch gradientFrom {
        case .topLeft:  return UnitPoint(x: 0.3, y: 0.2)
        case .topRight: return UnitPoint(x: 0.8, y: 0.3)
        case .center:   return .center
        }
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(
                        RadialGradient(
                            colors: [Color.movo.elevated, Color.movo.background],
                            center: startPoint,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
            )
    }
}

extension View {
    public func cardSurface(padding: CGFloat = Spacing.cardPadding,
                            radius: CGFloat = Radius.card) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }

    public func heroCard(gradientFrom: HeroCard.Direction = .topLeft,
                        radius: CGFloat = Radius.heroCard) -> some View {
        modifier(HeroCard(gradientFrom: gradientFrom, radius: radius))
    }
}

// MARK: - Background

/// Cinematic dashboard background — soft top glow fading to deep base.
public struct MovoBackground: View {
    public init() {}
    public var body: some View {
        RadialGradient(
            colors: [Color.movo.textPrimary.opacity(0.04), Color.movo.background],
            center: .top,
            startRadius: 0,
            endRadius: 600
        )
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

/// Primary CTA — large pill-shaped button on accent fill.
public struct MovoPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.buttonLarge)
            .foregroundColor(Color.movo.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .fill(Color.movo.accent.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: DesignTokens.Motion.fast),
                       value: configuration.isPressed)
    }
}

// MARK: - Outline button style (Log In)

public struct OutlineButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.buttonLarge)
            .foregroundColor(Color.movo.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: Radius.heroCard)
                    .fill(Color.movo.elevated.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .stroke(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.heroCard))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: DesignTokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Compact primary — for in-form actions (Add Contact, Confirm).
public struct MovoCompactButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundColor(Color.movo.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.accent.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

/// Soft accent outline — accent-color label and hairline border on transparent fill.
/// Use for secondary/empty-state CTAs that need to telegraph "this is the action"
/// without competing with the primary accent-filled CTA on screen.
public struct SoftAccentButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundColor(Color.movo.accent)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline + 0.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: DesignTokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Secondary — neutral pill, less visual weight.
public struct MovoSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundColor(Color.movo.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.elevated.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// Tertiary text-only button (for low-priority actions like "View receipt").
public struct MovoTextButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.bodyCompact)
            .foregroundColor(Color.movo.accent)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Status pill

/// Inline status pill (Completed / Pending / Failed / On Movo / Recommended).
public struct StatusPill: View {
    public enum Variant {
        case accent, neutral, success, danger, warning
    }

    public let label: String
    public let variant: Variant
    public let icon: String?

    public init(_ label: String, variant: Variant = .accent, icon: String? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .textStyle(Typography.eyebrow)
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(bgColor)
                .overlay(
                    Capsule().strokeBorder(borderColor, lineWidth: Stroke.hairline)
                )
        )
    }

    private var bgColor: Color {
        switch variant {
        case .accent:  return Color.movo.accentTint
        case .neutral: return Color.movo.elevated.opacity(0.6)
        case .success: return Color.movo.successTint
        case .danger:  return Color.movo.dangerTint
        case .warning: return Color.movo.warning.opacity(0.12)
        }
    }
    private var borderColor: Color {
        switch variant {
        case .accent:  return Color.movo.accentBorder
        case .neutral: return Color.movo.border
        case .success: return Color.movo.accentBorder
        case .danger:  return Color.movo.danger.opacity(0.3)
        case .warning: return Color.movo.warning.opacity(0.3)
        }
    }
    private var textColor: Color {
        switch variant {
        case .accent, .success: return Color.movo.accent
        case .neutral: return Color.movo.textTertiary
        case .danger:  return Color.movo.danger
        case .warning: return Color.movo.warning
        }
    }
}

// MARK: - Sheet dim scrim

/// Darkens the background when a sheet or overlay is presented.
/// Apply once on the root content view; pass `isActive` from any Bool state binding.
///
/// Usage:
///   ```swift
///   ContentView()
///       .dimmingOverlay(isActive: showSheet)
///       .sheet(isPresented: $showSheet) { ... }
///   ```
public struct DimmingOverlay: ViewModifier {
    let isActive: Bool

    public func body(content: Content) -> some View {
        ZStack {
            content
            if isActive {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: isActive)
    }
}

extension View {
    /// Fades a dark scrim over this view when `isActive` is true.
    /// Chain before `.sheet()` / `.fullScreenCover()` modifiers.
    public func dimmingOverlay(isActive: Bool) -> some View {
        modifier(DimmingOverlay(isActive: isActive))
    }
}

// MARK: - Eyebrow label

/// Small uppercase tracked label (e.g., "WELCOME", "RECOMMENDED").
public struct Eyebrow: View {
    public let text: String
    public let color: Color
    public init(_ text: String, color: Color = Color.movo.textTertiary) {
        self.text = text
        self.color = color
    }
    public var body: some View {
        Text(text.uppercased())
            .textStyle(Typography.eyebrow)
            .foregroundColor(color)
    }
}
