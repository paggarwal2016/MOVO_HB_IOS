//
//  BalanceText.swift
//  MovocashIOS
//

import SwiftUI
import UIKit

/// Renders a Decimal balance as a single rich-text line:
/// dollars in `dollarSize`, cents in `centsSize`, same color.
/// Formatting is deterministic (en_US locale, 2 dp) regardless of device locale.
///
/// Dynamic Type: sizes scale via UIFontMetrics relative to .largeTitle (dollars)
/// and .title1 (cents). At the default content size the rendered size is unchanged;
/// at larger accessibility sizes both parts scale proportionally.
/// The container is responsible for accommodating the larger text — this view
/// never shrinks its text to fit (minimumScaleFactor is intentionally absent).
struct BalanceText: View {

    let amount: Decimal
    var dollarSize: CGFloat = 40
    var centsSize:  CGFloat = 22
    var color: Color = Color.movo.textPrimary
    var centsOpacity: Double = 1.0

    // Re-renders this view when the user's Dynamic Type setting changes so that
    // UIFontMetrics.scaledValue returns the updated size on each body evaluation.
    @Environment(\.sizeCategory) private var sizeCategory

    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        // Explicit read ensures SwiftUI tracks sizeCategory as a dependency.
        // UIFontMetrics reads UIKit's preferredContentSizeCategory, which is
        // always in sync with the SwiftUI environment value by the time body runs.
        let _ = sizeCategory
        let scaledDollar = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: dollarSize)
        let scaledCents  = UIFontMetrics(forTextStyle: .title1).scaledValue(for: centsSize)

        let f        = Self.fmt
        let full     = f.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
        let sep      = f.currencyDecimalSeparator ?? "."
        let sepRange = full.range(of: sep, options: .backwards)

        // ViewThatFits picks the layout, not per-node atomicity.
        // .lineLimit(1) on each part is the actual guard: if a dollars node alone
        // is wider than the container, it cannot wrap internally — the whole
        // candidate is rejected and the VStack fallback is chosen instead.
        // Without .lineLimit(1) a wide single-node could still break mid-digit.
        //
        // VoiceOver: .accessibilityElement(children: .ignore) + .accessibilityLabel
        // re-joins the two Text nodes into one utterance ("$10,183.58").
        // Without this, screen readers announce dollars and cents as separate elements.
        ViewThatFits(in: .horizontal) {
            // Candidate 1 — preferred: dollars + cents on one line.
            Group {
                if let r = sepRange {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(full[..<r.lowerBound])
                            .font(.system(size: scaledDollar, weight: .bold).monospacedDigit())
                            .tracking(-1.0)
                            .lineLimit(1)
                        Text(full[r.lowerBound...])
                            .font(.system(size: scaledCents, weight: .bold).monospacedDigit())
                            .tracking(-1.0)
                            .foregroundColor(color.opacity(centsOpacity))
                            .lineLimit(1)
                    }
                    .foregroundColor(color)
                } else {
                    Text(full)
                        .font(.system(size: scaledDollar, weight: .bold).monospacedDigit())
                        .tracking(-1.0)
                        .foregroundColor(color)
                        .lineLimit(1)
                }
            }
            // Candidate 2 — fallback: dollars on line 1, cents on line 2.
            Group {
                if let r = sepRange {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(full[..<r.lowerBound])
                            .font(.system(size: scaledDollar, weight: .bold).monospacedDigit())
                            .tracking(-1.0)
                            .foregroundColor(color)
                            .lineLimit(1)
                        Text(full[r.lowerBound...])
                            .font(.system(size: scaledCents, weight: .bold).monospacedDigit())
                            .tracking(-1.0)
                            .foregroundColor(color.opacity(centsOpacity))
                            .lineLimit(1)
                    }
                } else {
                    Text(full)
                        .font(.system(size: scaledDollar, weight: .bold).monospacedDigit())
                        .tracking(-1.0)
                        .foregroundColor(color)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(full)
        // minimumScaleFactor intentionally absent — shrinking text defeats Dynamic Type (WCAG 1.4.4).
    }
}
