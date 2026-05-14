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
        HStack(alignment: .center, spacing: 16) {
            PayAnyoneIllustration()
                .frame(width: 80, height: 80)
                .frame(maxWidth: .none, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .textStyle(Typography.cardHero)
                    .foregroundStyle(theme.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .textStyle(Typography.subtitle)
                    .foregroundStyle(theme.textSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onButtonTap) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: theme.background.color))
                                .scaleEffect(0.8)
                        } else {
                            Text(buttonLabel)
                                .textStyle(Typography.button)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(theme.background.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevated.color)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderStrong.color, lineWidth: DesignTokens.Stroke.hairline)
        )
        .padding(.horizontal, 15)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Color.movo.textTertiary)
                .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.lg) {
                    ForEach(contacts) { contact in
                        let initial = String(
                            contact.nickname?.first ?? contact.phoneNumber?.first ?? "?"
                        ).uppercased()
                        let label = contact.nickname ?? contact.phoneNumber ?? ""
                        bubble(initial: initial, label: label) { onContactTap(contact) }
                    }
                    bubble(initial: "+", label: "Add", action: onAddTap)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
    }

    private func bubble(initial: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(Color.movo.elevated)
                        .frame(width: 52, height: 52)
                    Text(initial)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.movo.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}
