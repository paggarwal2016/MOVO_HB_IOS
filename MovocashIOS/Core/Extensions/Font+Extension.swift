//
//  Font+Extension.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/05/26.
//

import Foundation
import SwiftUI

enum AppFont {

    // MARK: - Global scale knob
    //
    // Change this single value to proportionally rescale every Montserrat token
    // app-wide. Tracking literals in appStyle also reference the size constants
    // below, so letter-spacing scales automatically with point size.
    //
    // EXCEPTION: BalanceText (home hero balance, UIFontMetrics 38pt / 30pt) is NOT
    // wired to this knob — it calls UIFontMetrics directly for tile-frame-aware
    // scaling. A global "make everything bigger" change must update BalanceText
    // (dollarSize / centsSize) separately.
    private static let scale: CGFloat = 1.0

    // MARK: - Canonical base sizes
    //
    // Edit here only. AppFont tokens (below) and Font+Modifier.swift both reference
    // these — single source of truth. rowTitle / rowValue share bodySize; ctaSize
    // is independent so button labels can be tuned without touching reading text.
    static let bodySize:      CGFloat = ceil(17 * scale)   // anchor — Apple standard body
    static let ctaSize:       CGFloat = ceil(16 * scale)   // button labels; decoupled from body
    static let captionSize:   CGFloat = ceil(14 * scale)
    static let labelCapsSize: CGFloat = ceil(11 * scale)
    static let heroSize:      CGFloat = ceil(20 * scale)
    static let balanceSize:   CGFloat = ceil(34 * scale)

    // MARK: - Role tokens

    /// 16pt SemiBold — CTA buttons ("ADD MONEY", "LET'S MOVO", "TRANSFER")
    static let cta       = Font.custom("Montserrat-SemiBold", size: ctaSize,       relativeTo: .callout)

    /// 17pt Medium — row and card-face labels (card name, merchant name, greeting name)
    static let rowTitle  = Font.custom("Montserrat-Medium",   size: bodySize,      relativeTo: .callout)

    /// 17pt SemiBold — row value text; ≥ rowTitle by weight — amounts never render smaller than their label
    static let rowValue  = Font.custom("Montserrat-SemiBold", size: bodySize,      relativeTo: .callout)

    /// 17pt Regular — primary body copy
    static let body      = Font.custom("Montserrat-Regular",  size: bodySize,      relativeTo: .body)

    /// 14pt Regular — secondary captions and helper text
    static let caption   = Font.custom("Montserrat-Regular",  size: captionSize,   relativeTo: .footnote)

    /// 11pt SemiBold — ALL-CAPS eyebrow labels (section headers, greeting subtitle, tab labels)
    static let labelCaps = Font.custom("Montserrat-SemiBold", size: labelCapsSize, relativeTo: .caption2)

    // MARK: - Display / hero (exception — base sizes are load-bearing)

    /// 20pt SemiBold — card section titles, sheet heroes
    static let hero      = Font.custom("Montserrat-SemiBold", size: heroSize,      relativeTo: .title2)

    /// 34pt SemiBold — balance display (AppFont layer only; large hero balances use BalanceText)
    static let balance   = Font.custom("Montserrat-SemiBold", size: balanceSize,   relativeTo: .largeTitle)

    // MARK: - System fonts (SF Pro — tabular figures and card digits)

    /// SF Pro .callout — currency amounts in activity rows; SF tabular figures are preferred over Montserrat
    static let activityAmount = Font.system(.callout, weight: .medium)

    /// SF Pro .footnote monospaced — card number display
    static let cardNumber     = Font.system(.footnote, design: .monospaced)
}

struct Tracking {
    static func value(_ em: Double, size: CGFloat) -> CGFloat {
        return em * size
    }
}

extension Font {
    enum MontserratWeight: String {
        case regular  = "Montserrat-Regular"
        case medium   = "Montserrat-Medium"
        case semiBold = "Montserrat-SemiBold"
        case bold     = "Montserrat-Bold"
    }

    static func montserrat(_ weight: MontserratWeight = .regular, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(weight.rawValue, size: size, relativeTo: style)
    }
}


extension Text {

    @ViewBuilder
    func appStyle(_ style: AppTextStyle) -> some View {
        switch style {

        // ALL-CAPS eyebrow / section header / tab label
        case .labelCaps:
            self
                .tracking(Tracking.value(0.08, size: AppFont.labelCapsSize))
                .textCase(.uppercase)
                .movoFont(.labelCaps)

        case .balance:
            self
                .monospacedDigit()
                .tracking(Tracking.value(-0.02, size: AppFont.balanceSize))
                .movoFont(.balance)

        case .hero:
            self
                .tracking(Tracking.value(-0.01, size: AppFont.heroSize))
                .movoFont(.hero)

        case .body:
            self.movoFont(.body)

        case .caption:
            self.movoFont(.caption)

        // CTA buttons — slight positive tracking for button labels
        case .cta:
            self
                .tracking(Tracking.value(0.02, size: AppFont.ctaSize))
                .movoFont(.cta)

        case .rowTitle:
            self.movoFont(.rowTitle)

        case .rowValue:
            self.movoFont(.rowValue)

        case .activityAmount:
            self
                .monospacedDigit()
                .movoFont(.activityAmount)

        case .cardNumber:
            self
                .tracking(Tracking.value(0.16, size: 9))   // system font — not Montserrat-scaled
                .movoFont(.cardNumber)
        }
    }
}


enum AppTextStyle {
    case cta
    case rowTitle
    case rowValue
    case body
    case caption
    case labelCaps
    case hero
    case balance
    case activityAmount
    case cardNumber
}
