//
//  LimitNoticeBanner.swift
//  MovocashIOS
//
//  Presentational-only notice banner shown above the Transfer button in
//  FundAccountView. It is purely informational — it does not gate, disable,
//  or affect the transfer flow in any way.
//
//  To update the limit amount, phone display string, or dial digits, change
//  LimitNoticeConfig below. Do not inline literals in the view body.
//

import SwiftUI

// MARK: - Configuration

private enum LimitNoticeConfig {
    /// Displayed limit amount (e.g. "$200"). Update here, not in the view.
    static let dailyLimit          = "$200"
    /// Human-readable phone string shown in the banner text.
    static let supportPhoneDisplay = "(866) 348-3435"
    /// Digits used in the tel: URL — no spaces, no dashes.
    static let supportPhoneDial    = "+18663483435"
}

// MARK: - View

struct LimitNoticeBanner: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.movo.warning)
                .padding(.top, 1)   // optical alignment with the first text baseline

            noticeText
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.movo.warningBackground)
        )
        // Accessibility: expose the whole banner as a single static element
        // with a named custom action so VoiceOver users can dial without
        // navigating inside the text.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Daily transfer limit \(LimitNoticeConfig.dailyLimit). " +
            "Temporary, will be lifted soon. " +
            "Contact support with questions."
        )
        .accessibilityAction(named: Text("Call support")) { dialSupport() }
    }

    // MARK: - Inline text with tappable phone span

    private var noticeText: some View {
        var attr = AttributedString(
            "Daily transfer limit: \(LimitNoticeConfig.dailyLimit). " +
            "Temporary \u{2014} will be lifted soon. " +
            "Contact support at \(LimitNoticeConfig.supportPhoneDisplay) with questions."
        )
        // Underline + link only the phone number span; the rest is plain text.
        if let range = attr.range(of: LimitNoticeConfig.supportPhoneDisplay) {
            attr[range].underlineStyle = .single
            attr[range].link = URL(string: "tel:\(LimitNoticeConfig.supportPhoneDial)")
        }
        return Text(attr)
            .font(.caption)                       // semantic style — scales with Dynamic Type
            .foregroundStyle(Color.movo.warning)  // amber for all text
            .tint(Color.movo.warning)             // keeps link span amber, not system blue
    }

    // MARK: - Helpers

    private func dialSupport() {
        guard let url = URL(string: "tel:\(LimitNoticeConfig.supportPhoneDial)") else { return }
        openURL(url)
    }
}
