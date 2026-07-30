//
//  CustomHeaderView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI
import UIKit

struct CustomHeaderView: View {

    // MARK: - Properties

    var userName: String = ""
    var userImage: String = ""
    var onProfileTap: () -> Void

    private let theme = MovoTheme.color

    private var initial: String {
        userName.first.map(String.init)?.uppercased() ?? "?"
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center) {

            HStack(alignment: .center, spacing: 4) {
                HerringLogoWithFDIC()

                VStack(alignment: .leading, spacing: 0) {
                    Text("MOVOCASH")
                        .font(.system(size: 21, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Color.movo.textPrimary)

                    Text("Powered by HyperBin\u{00AE}")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                        .offset(y: -2)
                }
            }

            Spacer()

            // Right — initial avatar (taps to open the Settings/profile tab)
            Button(action: onProfileTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.movo.surface)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.movo.accent, lineWidth: 1.5)
                        )

                    Text(initial)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(theme.textPrimary.color)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Private subviews

/// Herring Bank logo scaled 2% larger than the original 40.8pt,
/// with "Member FDIC" curved along the bottom arc.
private struct HerringLogoWithFDIC: View {
    // 42.6 × 1.02 = 43.452 → 43.5pt
    private static let logoSize: CGFloat = 43.5
    // 9pt semibold with wider tracking — built from design-token primitives,
    // not hardcoded: size matches Typography.micro, weight stepped up to semibold.
    private static let textStyle: TextStyle = TextStyle(
        size: Typography.micro.size,
        weight: .semibold,
        tracking: Typography.micro.tracking
    )
    // Arc radius: logo edge + half character height + 1pt clearance
    private static let textRadius: CGFloat = logoSize / 2 + textStyle.size / 2 + 1

    var body: some View {
        ZStack {
            Image("herringLogo")
                .resizable()
                .scaledToFit()
                .frame(width: Self.logoSize, height: Self.logoSize)

            CurvedTextArc(
                text: "Member FDIC",
                style: Self.textStyle,
                radius: Self.textRadius,
                centerAngle: 180
            )
            .foregroundColor(Color.movo.textTertiary)
        }
        // Symmetric frame gives the bottom arc enough room without clipping
        .frame(
            width:  Self.logoSize + Self.textStyle.size * 2 + 4,
            height: Self.logoSize + Self.textStyle.size * 2 + 4
        )
    }
}

/// Renders each character of `text` along a circular arc using the real
/// UIFont advance width of each glyph, so narrow letters (r, i) and wide
/// letters (m, M) are spaced proportionally — not uniformly.
///
/// - Parameters:
///   - text: The string to render along the arc.
///   - style: A `TextStyle` design token — determines font size and weight.
///   - radius: Distance from the ZStack centre to each character's centre.
///   - centerAngle: Degrees clockwise from 12 o'clock where the arc midpoint sits.
///                  0 = top, 90 = right, 180 = bottom, 270 = left.
private struct CurvedTextArc: View {
    let text: String
    let style: TextStyle
    let radius: CGFloat
    let centerAngle: Double

    private var chars: [Character] { Array(text) }

    // UIFont matching the TextStyle — used for per-glyph advance measurement.
    private var uiFont: UIFont {
        let w: UIFont.Weight
        switch style.weight {
        case .ultraLight: w = .ultraLight
        case .thin:       w = .thin
        case .light:      w = .light
        case .medium:     w = .medium
        case .semibold:   w = .semibold
        case .bold:       w = .bold
        case .heavy:      w = .heavy
        case .black:      w = .black
        default:          w = .regular
        }
        return UIFont.systemFont(ofSize: style.size, weight: w)
    }

    /// Real advance width of a character.
    /// Space is capped at 30 % of the font size so the word gap stays tight.
    private func advance(_ c: Character) -> Double {
        guard c != " " else { return Double(style.size) * 0.3 }
        return Double((String(c) as NSString)
            .size(withAttributes: [.font: uiFont]).width)
    }

    private var totalAdvance: Double { chars.reduce(0) { $0 + advance($1) } }

    /// Total arc span in degrees based on actual text width vs circumference.
    private var arcSpan: Double {
        let circumference = 2 * .pi * Double(radius)
        return (totalAdvance / circumference) * 360
    }

    /// Cumulative advance midpoint for each character — drives arc position.
    private var midpoints: [Double] {
        var result: [Double] = []
        var running = 0.0
        for c in chars {
            let w = advance(c)
            result.append(running + w / 2)
            running += w
        }
        return result
    }

    var body: some View {
        let mids = midpoints
        let total = totalAdvance
        ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, char in
                let fraction = total > 0 ? mids[i] / total : 0.5
                let angle    = centerAngle + arcSpan / 2 - fraction * arcSpan
                let rad      = angle * .pi / 180

                Text(String(char))
                    .font(style.font)
                    // angle - 180 orients each glyph so its top faces the centre
                    // (readable from outside). Arc runs counter-clockwise so
                    // characters read left-to-right as seen by the viewer.
                    .rotationEffect(.degrees(angle - 180))
                    .offset(
                        x:  CGFloat(sin(rad)) * radius,
                        y: -CGFloat(cos(rad)) * radius
                    )
            }
        }
    }
}
