//
//  LimitNoticeBanner.swift
//  MovocashIOS
//
import SwiftUI

// MARK: - View

struct LimitNoticeBanner: View {
    
    private let dailyLimit = "$200"

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
            "Daily transfer limit \(dailyLimit). " +
            "Temporary, will be lifted soon. " +
            "Contact support with questions."
        )
        .accessibilityAction(named: Text("Call support")) { dialSupport() }
    }

    // MARK: - Inline text with tappable phone span

    private var noticeText: some View {
        var attr = AttributedString(
            "Daily transfer limit: \(dailyLimit). " +
            "Temporary \u{2014} will be lifted soon. " +
            "Contact support at \(AppConfig.customerCare) with questions."
        )
        // Underline + link only the phone number span; the rest is plain text.
        if let range = attr.range(of: AppConfig.customerCare) {
            attr[range].underlineStyle = .single
            attr[range].link = URL(string: AppConfig.customerCareNumber)
        }
        return Text(attr)
            .font(.caption)                       // semantic style — scales with Dynamic Type
            .foregroundStyle(Color.movo.warning)  // amber for all text
            .tint(Color.movo.warning)             // keeps link span amber, not system blue
    }

    // MARK: - Helpers

    private func dialSupport() {
        guard let url = URL(string: AppConfig.customerCareNumber) else { return }
        openURL(url)
    }
}
