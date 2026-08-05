//
//  MovoLabels.swift
//  MovocashIOS
//
//  Three reusable label primitives for the Movo design system.
//  Each serves exactly one semantic role — type, status, or action —
//  so they can never be confused or swapped in code review.
//
//  MovoTypeBadge   — metadata / category  (border-only, no fill, no green)
//  MovoStatusLabel — live state indicator (dot + text, no border)
//  MovoActionButton — tappable secondary  (elevated pill, 44pt tap target)
//

import SwiftUI

// MARK: - MovoTypeBadge

/// Displays a metadata label such as "VIRTUAL", "PRIMARY", or "SAVINGS".
/// Plain caps text — no fill, no border, no green.
public struct MovoTypeBadge: View {

    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.6)
            .foregroundColor(DesignTokens.Palette.typeBadgeText.color)
    }
}

// MARK: - MovoStatusLabel

public enum MovoStatus {
    case active
    // Future: case pending, case frozen

    var label: String {
        switch self {
        case .active: return "Active"
        }
    }

    var color: Color {
        switch self {
        case .active: return DesignTokens.Palette.accent.color
        }
    }
}

/// Displays a live account/card status as a dot + text.
/// No border, no pill background — the glowing dot is the signal.
public struct MovoStatusLabel: View {

    let status: MovoStatus

    public init(_ status: MovoStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .shadow(color: status.color.opacity(0.7), radius: 3, x: 0, y: 0)

            Text(status.label)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.48)
                .foregroundColor(status.color)
        }
    }
}

// MARK: - MovoActionButton

/// Tappable secondary action button.
/// Visible pill is ~33pt tall; tap target is always 44pt (accessible).
/// Dark: slate fill + greenLight text + drop shadow.
/// Light: tonal green fill + green border + deep-green text + no shadow.
public struct MovoActionButton: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // ── Inner pill (visible only — no minHeight here) ────────────────
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(DesignTokens.Palette.actionText.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                MovoChevron(.disclosure, color: DesignTokens.Palette.actionText.color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(DesignTokens.Palette.actionFill.color)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(DesignTokens.Palette.actionBorder.color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: colorScheme == .dark ? 8 : 2,
                x: 0, y: 2
            )
            // ── Outer tap area (enlarges hit region, invisible) ──────────────
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
