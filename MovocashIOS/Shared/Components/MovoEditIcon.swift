//
//  MovoEditIcon.swift
//  MovocashIOS
//
//  Reusable Movo pencil / edit icon.
//  Custom Path only — no SF Symbols, no Image(systemName:).
//
//  ViewBox: 0 0 24 24
//
//  Pencil geometry (all coordinates in the 24 × 24 unit grid):
//
//    Axis:  45 ° diagonal, eraser top-right → nib bottom-left.
//           Eraser centre E = (17, 7), Ferrule centre F = (8, 16), Nib tip T = (5, 19).
//           Axis unit vector:        (−0.707,  0.707)
//           Perpendicular (right):   ( 0.707,  0.707)
//           Barrel half-width w = 1.5  →  screen offset ±(1.5, 1.5)
//
//    A = (15.5,  5.5)  eraser left   = E − (1.5, 1.5)
//    B = (18.5,  8.5)  eraser right  = E + (1.5, 1.5)
//    C = ( 9.5, 17.5)  ferrule right = F + (1.5, 1.5)
//    D = ( 6.5, 14.5)  ferrule left  = F − (1.5, 1.5)
//    T = ( 5.0, 19.0)  nib tip       = F + 3·(−0.707, 0.707)
//
//    Outline (closed):   A → B  (eraser cap, ⊥ axis)
//                        B → C  (right barrel edge, ∥ axis)
//                        C → T  (right nib edge → tip)
//                        T → D  (left  nib edge ← tip)
//                        D → A  (left  barrel edge, ∥ axis)  [closeSubpath]
//
//    Ferrule sub-path:   C → D  (nib / barrel separator)
//
//    Nib angle at T ≈ 53 ° — clear taper without being fragile at small sizes.
//    Stroke: round lineCap, round lineJoin.  lineWidth = size × 0.09.
//

import SwiftUI

// MARK: - Shape

private struct EditIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 24
        let sy = rect.height / 24

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var p = Path()

        // ── Barrel + nib outline (closed) ────────────────────────
        p.move(to:    pt(15.5,  5.5))   // A  eraser left
        p.addLine(to: pt(18.5,  8.5))   // B  eraser right  → eraser cap (A→B)
        p.addLine(to: pt( 9.5, 17.5))   // C  ferrule right → right barrel edge (B→C)
        p.addLine(to: pt( 5.0, 19.0))   // T  nib tip       → right nib edge (C→T)
        p.addLine(to: pt( 6.5, 14.5))   // D  ferrule left  → left nib edge (T→D)
        p.closeSubpath()                // → A left barrel edge (D→A)

        // ── Ferrule cross-line (nib / barrel separator) ──────────
        p.move(to:    pt( 9.5, 17.5))   // C
        p.addLine(to: pt( 6.5, 14.5))   // D

        return p
    }
}

// MARK: - View

/// Movo system edit / pencil icon. Stroke only, no fill. Adaptive to light and dark
/// via the existing `Color.movo` token system — no hardcoded hex values.
///
/// ```swift
/// MovoEditIcon()                                    // 20 pt, accent green
/// MovoEditIcon(size: 16)
/// MovoEditIcon(size: 28, tint: Color.movo.textSecondary)
/// ```
public struct MovoEditIcon: View {

    /// Side length of the square frame in points.
    public let size: CGFloat
    /// Stroke colour. Defaults to the app accent green token.
    public let tint: Color

    public init(size: CGFloat = 20, tint: Color = Color.movo.accent) {
        self.size = size
        self.tint = tint
    }

    /// Stroke weight proportional to size so the icon reads at every scale.
    private var lineWidth: CGFloat { size * 0.09 }

    public var body: some View {
        EditIconShape()
            .stroke(
                tint,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap:   .round,
                    lineJoin:  .round
                )
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("MovoEditIcon") {
    VStack(spacing: 28) {

        // Dark surface (#0F0F14)
        VStack(spacing: 4) {
            Text("Dark surface  ·  16 / 20 / 28 pt")
                .font(.caption2)
                .foregroundColor(.gray)
            HStack(spacing: 28) {
                MovoEditIcon(size: 16)
                MovoEditIcon(size: 20)
                MovoEditIcon(size: 28)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.sRGB, red: 0.059, green: 0.059, blue: 0.078, opacity: 1))
            )
        }

        // Light surface (#F2F3F6)
        VStack(spacing: 4) {
            Text("Light surface  ·  16 / 20 / 28 pt")
                .font(.caption2)
                .foregroundColor(.gray)
            HStack(spacing: 28) {
                MovoEditIcon(size: 16)
                MovoEditIcon(size: 20)
                MovoEditIcon(size: 28)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.sRGB, red: 0.949, green: 0.953, blue: 0.965, opacity: 1))
            )
        }

        // Tint variants on dark
        VStack(spacing: 4) {
            Text("Tint variants")
                .font(.caption2)
                .foregroundColor(.gray)
            HStack(spacing: 28) {
                MovoEditIcon(size: 20)
                MovoEditIcon(size: 20, tint: Color.movo.textSecondary)
                MovoEditIcon(size: 20, tint: Color.movo.textTertiary)
                MovoEditIcon(size: 20, tint: .white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.sRGB, red: 0.059, green: 0.059, blue: 0.078, opacity: 1))
            )
        }
    }
    .padding()
    .background(Color(.sRGB, red: 0.1, green: 0.1, blue: 0.12, opacity: 1))
}
