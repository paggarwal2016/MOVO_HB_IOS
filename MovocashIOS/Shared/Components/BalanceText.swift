//
//  BalanceText.swift
//  MovocashIOS
//

import SwiftUI

/// Renders a Decimal balance as a single rich-text line:
/// dollars in `dollarSize`, cents in `centsSize`, same color.
/// Formatting is deterministic (en_US locale, 2 dp) regardless of device locale.
struct BalanceText: View {

    let amount: Decimal
    var dollarSize: CGFloat = 40
    var centsSize:  CGFloat = 22
    var color: Color = Color.movo.textPrimary
    var centsOpacity: Double = 1.0

    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        let f    = Self.fmt
        let full = f.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
        let sep  = f.currencyDecimalSeparator ?? "."
        let text: Text = {
            guard let r = full.range(of: sep, options: .backwards) else {
                return Text(full)
                    .font(.system(size: dollarSize, weight: .bold).monospacedDigit())
            }
            return Text(full[..<r.lowerBound])
                        .font(.system(size: dollarSize, weight: .bold).monospacedDigit())
                 + Text(full[r.lowerBound...])
                        .font(.system(size: centsSize, weight: .bold).monospacedDigit())
                        .foregroundColor(color.opacity(centsOpacity))
        }()
        text
            .tracking(-1.0)
            .foregroundColor(color)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}
