//
//  ActionCard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 25/03/26.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    var isLoading: Bool = false
    var onButtonTap: () -> Void = {}

    private let theme = MovoTheme.color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section eyebrow — the tile title (e.g. "QUICK SEND").
            Text(title.uppercased())
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)

            // Inner card — tappable empty state.
            Button(action: onButtonTap) {
                VStack(spacing: Spacing.sm) {
                    // Circular tinted badge holding the add-person glyph.
                    ZStack {
                        Circle()
                            .fill(Color.movo.accentTint)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color.movo.accent)
                    }
                    .frame(width: 40, height: 40)
                    .padding(.top, Spacing.md)

                    // Message — the section's `description` (e.g. "No recent contacts yet").
                    // +3pt over Typography.subtitle (13pt regular, tracking 0)
                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 16, weight: .regular))
                            .tracking(0)
                            .foregroundStyle(theme.textSecondary.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Accent action — the API action's `label` (e.g. "Add someone").
                    // +3pt over Typography.button (12pt semibold, tracking 0.2)
                    Text(buttonLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.movo.accent)
                        .padding(.bottom, Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.lg)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: DesignTokens.Palette.cardVoidTop.color,    location: 0.00),
                            .init(color: DesignTokens.Palette.cardVoidMid.color,    location: 0.55),
                            .init(color: DesignTokens.Palette.cardVoidBottom.color, location: 1.00)
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                        .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: DesignTokens.Stroke.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Illustration
public struct PayAnyoneIllustration: View {

    public init() {}

    public var body: some View {

        Canvas { context, size in
            // Base coordinate system: 80 × 60 (matches the SVG)
            let s = size.width / 80.0

            // ---------------- Left figure (dim / sender) ----------------
            drawFigure(in: &context.self,
                       center: CGPoint(x: 15 * s, y: 18 * s),
                       scale: s,
                       stroke: Color.movo.textTertiary,
                       lineWidth: 1.0)

            // ---------------- Right figure (bright / recipient) ----------------
            drawFigure(in: &context.self,
                       center: CGPoint(x: 60 * s, y: 20 * s),
                       scale: s,
                       stroke: Color.movo.textPrimary,
                       lineWidth: 1.0)

            // ---------------- Tilted $ banknote ----------------
            var bill = context
            bill.translateBy(x: 30 * s, y: 4 * s)
            bill.rotate(by: .degrees(-12))

            let billRect = CGRect(x: 0, y: 0, width: 22 * s, height: 13 * s)
            let billPath = Path(roundedRect: billRect, cornerRadius: 2 * s)
            bill.fill(billPath,  with: .color(Color.movo.surface))
            bill.stroke(billPath, with: .color(Color.movo.accent), lineWidth: 0.8)

            // $ circle on the bill
            let dollarCircle = Path(
                ellipseIn: CGRect(x: 7.8 * s, y: 3.3 * s,
                                  width: 6.4 * s, height: 6.4 * s)
            )
            bill.stroke(dollarCircle, with: .color(Color.movo.accent), lineWidth: 0.7)

            // $ glyph
            bill.draw(
                Text("$")
                    .font(.system(size: 5.5 * s, weight: .semibold))
                    .foregroundColor(Color.movo.accent),
                at: CGPoint(x: 11 * s, y: 6.5 * s)
            )
        }
        .aspectRatio(80.0 / 60.0, contentMode: .fit)
    }

    /// Draws one outlined figure: head circle + bell-curve body.
    /// All geometry derived from the 80×60 design space, multiplied by `scale`.
    private func drawFigure(in context: inout GraphicsContext,
                            center: CGPoint,
                            scale: CGFloat,
                            stroke: Color,
                            lineWidth: CGFloat) {
        // Head — radius 7 around the center
        let head = Path(
            ellipseIn: CGRect(
                x: center.x - 7 * scale,
                y: center.y - 7 * scale,
                width: 14 * scale,
                height: 14 * scale
            )
        )
        context.stroke(head, with: .color(stroke), lineWidth: lineWidth)

        // Body — a smooth bell shape from shoulders down, drawn with two
        // symmetric quadratic curves meeting at the top center.
        // Path moves bottom-left → top-center → bottom-right and closes.
        var body = Path()
        body.move(to: CGPoint(x: center.x - 11 * scale,
                              y: center.y + 28 * scale))
        body.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + 12 * scale),
            control: CGPoint(x: center.x - 11 * scale,
                             y: center.y + 12 * scale)
        )
        body.addQuadCurve(
            to: CGPoint(x: center.x + 11 * scale,
                        y: center.y + 28 * scale),
            control: CGPoint(x: center.x + 11 * scale,
                             y: center.y + 12 * scale)
        )
        context.stroke(
            body,
            with: .color(stroke),
            style: StrokeStyle(lineWidth: lineWidth,
                               lineCap: .round,
                               lineJoin: .round)
        )
    }
}









struct PayAnyoneAddContactView: View {

    let title: String
    let contacts: [RecordContact]
    var onAddTap: () -> Void
    var onContactTap: (RecordContact) -> Void
    var onSeeAllTap: (() -> Void)? = nil

    /// Drop contacts whose number isn't a valid US (NANP) number.
    private var validContacts: [RecordContact] { contacts.filter { $0.hasValidPhone } }
    private var showSeeAll: Bool { validContacts.count >= 4 }
    private var displayedContacts: [RecordContact] { Array(validContacts.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            // Header
            HStack {
                Eyebrow(title)
                Spacer()
                if showSeeAll {
                    Button(action: { onSeeAllTap?() }) {
                        Eyebrow("SEE ALL")
                    }
                    .buttonStyle(.plain)
                }
            }

            // Bubbles — equal width when ≥4 contacts, fixed width otherwise
            HStack(spacing: 8) {
                ForEach(displayedContacts) { contact in
                    // No nickname → first local digit avatar + phone number label.
                    bubble(initial: contact.avatarInitial, label: contact.compactLabel, expand: showSeeAll) { onContactTap(contact) }
                }
                bubble(initial: "+", label: "Add", expand: showSeeAll, action: onAddTap)
            }
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                )
        )
    }

    private func bubble(initial: String, label: String, expand: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                if initial == "+" {
                    CircleIconAvatar(systemName: "plus", size: 44, tint: .accent)
                        .frame(width: 52, height: 52)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.movo.elevatedHigh)
                            .overlay(Circle().strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline))
                        Text(initial)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.movo.textPrimary)
                    }
                    .frame(width: 52, height: 52)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.movo.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: expand ? .infinity : 56)
        }
        .buttonStyle(.plain)
    }
}
