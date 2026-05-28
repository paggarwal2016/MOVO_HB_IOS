//
//  ThemePreview.swift
//  MovoCash
//
//  SwiftUI preview helper for verifying every screen in both light and dark
//  appearances side-by-side. Drop into any `#Preview` block instead of
//  rendering the view directly.
//
//  Usage:
//      #Preview {
//          ThemePreview {
//              DashboardView()
//          }
//      }
//
//  Or for a single mode during focused work:
//      #Preview("Dashboard — Dark") {
//          DashboardView().preferredColorScheme(.dark)
//      }
//

import SwiftUI

/// Renders the supplied view twice — once in dark, once in light —
/// each labeled, so reviewers can see both appearances at a glance.
public struct ThemePreview<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            content()
                .preferredColorScheme(.dark)
                .previewDisplayName("Void Silver — Dark")

            content()
                .preferredColorScheme(.light)
                .previewDisplayName("Void Silver — Light")
        }
    }
}

// MARK: - Convenience modifier for ad-hoc theme overrides

extension View {
    /// Forces a specific appearance for this subtree.
    /// Use for in-app theme toggles or testing without changing the system.
    public func movoTheme(_ scheme: SwiftUI.ColorScheme) -> some View {
        self.preferredColorScheme(scheme)
    }
}

// MARK: - Palette inspector (debug helper)

#if DEBUG
/// Renders the full Void Silver palette as labeled swatches.
/// Useful during integration QA to confirm tokens look right in both modes.
public struct PaletteInspector: View {
    public init() {}

    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let token: ColorToken
    }

    private var surfaces: [Row] {
        [
            Row(label: "background",   token: DesignTokens.Palette.background),
            Row(label: "surface",      token: DesignTokens.Palette.surface),
            Row(label: "elevated",     token: DesignTokens.Palette.elevated),
            Row(label: "elevatedHigh", token: DesignTokens.Palette.elevatedHigh),
        ]
    }

    private var text: [Row] {
        [
            Row(label: "textPrimary",   token: DesignTokens.Palette.textPrimary),
            Row(label: "textSecondary", token: DesignTokens.Palette.textSecondary),
            Row(label: "textTertiary",  token: DesignTokens.Palette.textTertiary),
            Row(label: "textDisabled",  token: DesignTokens.Palette.textDisabled),
        ]
    }

    private var accentAndStatus: [Row] {
        [
            Row(label: "accent",   token: DesignTokens.Palette.accent),
            Row(label: "onAccent", token: DesignTokens.Palette.onAccent),
            Row(label: "success",  token: DesignTokens.Palette.success),
            Row(label: "danger",   token: DesignTokens.Palette.danger),
            Row(label: "warning",  token: DesignTokens.Palette.warning),
        ]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Surfaces", rows: surfaces)
                section("Text", rows: text)
                section("Accent & Status", rows: accentAndStatus)
            }
            .padding(20)
        }
        .background(Color.movo.background.ignoresSafeArea())
    }

    private func section(_ title: String, rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundColor(Color.movo.textTertiary)
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(row.token.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.movo.border, lineWidth: 0.5)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.movo.textPrimary)
                        Text(String(format: "L #%06X · D #%06X",
                                    row.token.lightHex, row.token.darkHex))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.movo.textTertiary)
                    }
                    Spacer()
                }
            }
        }
    }
}

#Preview("Palette Inspector") {
    ThemePreview {
        PaletteInspector()
    }
}
#endif
