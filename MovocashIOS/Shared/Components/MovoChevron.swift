//
//  MovoChevron.swift
//  MovocashIOS
//
//  Reusable Movo system chevron.
//  Custom Path only — no SF Symbols, no Image(systemName:).
//
//  ViewBox: 0 0 14 14
//  Path:    M5 3 l4 4 -4 4   (right-pointing chevron)
//  Stroke:  round linecap, round linejoin, no fill.
//

import SwiftUI

// MARK: - Size variants

public enum MovoChevronSize {
    /// Extra-large chevron — 24×24 pt, stroke 2.3
    case large
    /// Large CTA chevron — 16×16 pt, stroke 2.0
    case cta
    /// Standard disclosure row chevron — 14×14 pt, stroke 1.75
    case disclosure
    /// Compact inline chevron — 12×12 pt, stroke 1.5
    case inline

    var side: CGFloat {
        switch self {
        case .large:       return 24
        case .cta:         return 16
        case .disclosure:  return 14
        case .inline:      return 12
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .large:       return 2.30
        case .cta:         return 2.00
        case .disclosure:  return 1.75
        case .inline:      return 1.50
        }
    }
}

// MARK: - Direction

public enum MovoChevronDirection {
    case right  // 0°   — default
    case left   // 180° — nav back
    case down   // 90°  — expand toggle
    case up     // 270° — collapse toggle

    var degrees: Double {
        switch self {
        case .right: return   0
        case .left:  return 180
        case .down:  return  90
        case .up:    return 270
        }
    }
}

// MARK: - Shape

/// Draws the chevron path scaled from a 14×14 viewBox to the render rect.
private struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 14
        let sy = rect.height / 14
        var p = Path()
        p.move(to:    CGPoint(x: 5 * sx, y:  3 * sy))
        p.addLine(to: CGPoint(x: 9 * sx, y:  7 * sy))
        p.addLine(to: CGPoint(x: 5 * sx, y: 11 * sy))
        return p
    }
}

// MARK: - View

/// Movo system chevron. Stroke only, no fill.
///
/// ```swift
/// MovoChevron(.disclosure)                           // right, green
/// MovoChevron(.disclosure, direction: .left)         // nav back
/// MovoChevron(.disclosure, direction: .down)         // expand toggle
/// MovoChevron(.cta, color: .white, direction: .right)
/// ```
///
/// `direction` is animation-friendly — wrap the call site in `withAnimation`
/// and SwiftUI rotates the frame smoothly.
public struct MovoChevron: View {
    private let size:      MovoChevronSize
    private let color:     Color
    private let direction: MovoChevronDirection

    public init(
        _ size: MovoChevronSize,
        color: Color = Color.movo.accent,
        direction: MovoChevronDirection = .right
    ) {
        self.size      = size
        self.color     = color
        self.direction = direction
    }

    public var body: some View {
        ChevronShape()
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth:  size.strokeWidth,
                    lineCap:    .round,
                    lineJoin:   .round
                )
            )
            .frame(width: size.side, height: size.side)
            .rotationEffect(Angle(degrees: direction.degrees))
    }
}
