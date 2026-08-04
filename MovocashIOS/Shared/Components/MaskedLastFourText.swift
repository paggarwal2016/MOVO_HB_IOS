//
//  MaskedLastFourText.swift
//  MovocashIOS
//

import SwiftUI

func maskedLastFourText(_ digits: some StringProtocol) -> Text {
    let dotSizes: [CGFloat] = [
        Typography.cardTitle.size,
        Typography.cardHero.size,
        Typography.sectionTitle.size,
        Typography.heroTitle.size
    ]
    return dotSizes.reduce(Text("")) { partial, size in
        partial + Text(".")
            .font(FontFamily.font(size: size, weight: Typography.cardHero.weight, design: Typography.cardHero.design))
            .tracking(Typography.cardHero.tracking)
    } + Text(" \(String(digits))")
        .font(Typography.cardHero.font)
        .tracking(Typography.cardHero.tracking)
}
