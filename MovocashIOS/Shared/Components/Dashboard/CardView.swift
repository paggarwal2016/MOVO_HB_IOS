//
//  CardVcard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/04/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Card Item

struct CardItemView: View {

    let card: VCardListResponse
    let isSelected: Bool
    /// Wired to the pre-existing card-detail handler in CardSelectorView / DashboardView.
    /// Nil-safe — nothing breaks if no handler is provided.
    var onDetail: (() -> Void)? = nil

    // Re-renders when Dynamic Type changes so UIFontMetrics.scaledValue
    // returns the current scaled size when styledBalance is evaluated.
    @Environment(\.sizeCategory) private var sizeCategory

    private var cardName: String {
        (card.savingsAccountNickname ?? card.name ?? card.displayName).uppercased()
    }

    var body: some View {
        ZStack {
            // ── Layer 1: surface gradient (topLeading → bottomTrailing) ──
            cardSurface

            // ── Layer 2: silver sheen — top-leading light sweep ──────────
            silverSheen

            // ── Layer 3: hairline top edge ────────────────────────────────
            hairlineEdge

            // ── Layer 5: content ──────────────────────────────────────────
            VStack(spacing: 0) {
                faceContent
                linkRow
            }
        }
        // Card tile is a fixed-proportion graphic (~165pt), not a reflow surface.
        // A tile-local xxLarge cap keeps content proportional within the fixed frame.
        // The full balance at AX2 is available on the uncapped CardDetailSheet.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .frame(minHeight: 165)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: Stroke.hairline)
        )
    }

    // MARK: - Face content (data only — no background)

    private var faceContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top row: fixed-size M mark + card name + "DIGITAL CASH" label.
            // .center alignment keeps the 19pt icon and scaled name at a shared midpoint.
            // Name truncates with tail ellipsis — long names are labels, not financial data.
            HStack(alignment: .center, spacing: Spacing.xs) {
                MovoMVSymbol()
                    .frame(width: 19, height: 19)
                Text(cardName)
                    .movoFont(.rowTitle)
                    .tracking(0.9)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Spacing.xs)
                virtualPill
            }

            Spacer(minLength: Spacing.md)

            // Balance — tight, cents de-emphasised
            styledBalance

            Spacer().frame(height: Spacing.sm)

            // Footer: masked number — silver neutral
            Text(card.maskedNumber)
                .font(.system(.subheadline, weight: .medium))
                .tracking(0.7)
                .foregroundColor(DesignTokens.Palette.silverTint.color)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .drawingGroup()
    }

    // MARK: - Surface layers

    /// LinearGradient: topLeading → bottomTrailing, three locked-dark stops.
    private var cardSurface: some View {
        LinearGradient.cardVoid
    }

    /// Faint silver light sweep anchored to top-leading corner.
    private var silverSheen: some View {
        RadialGradient(
            colors: [
                DesignTokens.Palette.silverTint.color.opacity(0.06),
                .clear
            ],
            center:      UnitPoint(x: 0.08, y: 0.08),
            startRadius: 0,
            endRadius:   120
        )
        .allowsHitTesting(false)
    }

    // MARK: - Hairline top edge

    /// 1pt silver gradient rule near the top: clear → silver 22% → clear.
    /// Inset 24pt each side. Purely decorative.
    private var hairlineEdge: some View {
        LinearGradient(
            colors: [
                .clear,
                DesignTokens.Palette.silverTint.color.opacity(0.22),
                .clear
            ],
            startPoint: .leading,
            endPoint:   .trailing
        )
        .frame(height: 1)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Styled balance

    /// Maps the SwiftUI sizeCategory environment value (which respects the tile-local
    /// .dynamicTypeSize cap) to a UITraitCollection so UIFontMetrics.scaledValue(for:compatibleWith:)
    /// returns sizes bounded by the cap. Without this, UIFontMetrics reads UIKit's system-wide
    /// preferredContentSizeCategory and bypasses any SwiftUI .dynamicTypeSize modifier.
    private var cappedTraitCollection: UITraitCollection {
        let uiCategory: UIContentSizeCategory
        switch sizeCategory {
        case .extraSmall:                            uiCategory = .extraSmall
        case .small:                                 uiCategory = .small
        case .medium:                                uiCategory = .medium
        case .large:                                 uiCategory = .large
        case .extraLarge:                            uiCategory = .extraLarge
        case .extraExtraLarge:                       uiCategory = .extraExtraLarge
        case .extraExtraExtraLarge:                  uiCategory = .extraExtraExtraLarge
        case .accessibilityMedium:                   uiCategory = .accessibilityMedium
        case .accessibilityLarge:                    uiCategory = .accessibilityLarge
        case .accessibilityExtraLarge:               uiCategory = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge:          uiCategory = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge:     uiCategory = .accessibilityExtraExtraExtraLarge
        @unknown default:                            uiCategory = .large
        }
        return UITraitCollection(preferredContentSizeCategory: uiCategory)
    }

    /// Tight balance display: full-weight dollars + de-emphasised cents.
    /// Falls back to a single Text if the value has no decimal point.
    @ViewBuilder
    private var styledBalance: some View {
        // sizeCategory read ensures SwiftUI re-evaluates when Dynamic Type changes.
        // scaledValue(for:compatibleWith:) uses cappedTraitCollection so the tile's
        // local .dynamicTypeSize(.xxLarge) cap is respected — the system UIKit value
        // is ignored here.
        let _ = sizeCategory
        let scaledDollars = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 38, compatibleWith: cappedTraitCollection)
        let scaledCents   = UIFontMetrics(forTextStyle: .title1).scaledValue(for: 30, compatibleWith: cappedTraitCollection)
        let raw = card.displayBalance
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        if let dotIdx = raw.lastIndex(of: ".") {
            let dollars = String(raw[raw.startIndex...dotIdx])
            let cents   = String(raw[raw.index(after: dotIdx)...])
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(dollars)
                    .font(.system(size: scaledDollars, weight: .bold).monospacedDigit())
                    .tracking(-0.5)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                Text(cents)
                    .font(.system(size: scaledCents, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
            }
        } else {
            Text(raw)
                .font(.system(size: scaledDollars, weight: .bold).monospacedDigit())
                .tracking(-0.5)
                .foregroundColor(Color.movo.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Virtual pill

    private var virtualPill: some View {
        MovoTypeBadge("DIGITAL CASH")
    }

    // MARK: - Link row

    /// Full-width tappable row. Fires the pre-existing card-detail handler.
    private var linkRow: some View {
        HStack(spacing: Spacing.xs) {
            Text("LET'S MOVO")
                .movoFont(.cta)
                .tracking(0.8)
                .foregroundColor(Color.movo.accent)
            Spacer()
            MovoChevron(.large)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .drawingGroup()
        .contentShape(Rectangle())
        .onTapGesture { onDetail?() }
    }
}

// MARK: - Card Selector

struct CardSelectorView: View {
    
    private static let maxVisible = 5
    
    @State private var selectedIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var targetOffset: CGFloat = 0
    
    let cards: [VCardListResponse]
    var sectionTitle: String = "CASH CARDS"
    var onTap: () -> Void
    var onEyeTap: ((VCardListResponse) -> Void)? = nil
    var onShowMore: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geo in

            let cardWidth = cards.count == 1 ? geo.size.width : geo.size.width - 56
            let cardStride = cardWidth + 8
            let visibleCards = Array(cards.prefix(CardSelectorView.maxVisible))
            let hasMore = cards.count > CardSelectorView.maxVisible

            VStack(alignment: .leading, spacing: Spacing.md) {

                // Header
                HStack {
                    Text(sectionTitle.uppercased())
                        .textStyle(Typography.eyebrow)
                        .foregroundColor(Color.movo.textTertiary)

                    Button(action: onTap) {
                        CircleIconAvatar(systemName: "plus", size: 24, tint: .accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if hasMore {
                        Button(action: { onShowMore?() }) {
                            Eyebrow("SEE ALL")
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Carousel: existing cards + create card slot at end
                HStack(spacing: 8) {
                    ForEach(visibleCards.indices, id: \.self) { index in
                        CardItemView(
                            card: visibleCards[index],
                            isSelected: selectedIndex == index,
                            onDetail: { onEyeTap?(visibleCards[index]) }
                        )
                        .frame(width: cardWidth)
                        .onTapGesture {
                            if selectedIndex == index {
                                onEyeTap?(visibleCards[index])
                            } else {
                                let peek: CGFloat = index == 0 ? 0 : 28
                                selectedIndex = index
                                withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                                    targetOffset = CGFloat(-index) * cardStride + peek
                                }
                            }
                        }
                    }


                }
                .offset(x: targetOffset + dragOffset)
                .frame(minHeight: 165, alignment: .leading)
                .clipped()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            guard dx > dy else { return }
                            let raw = value.translation.width
                            let maxIndex = visibleCards.count - 1
                            if (selectedIndex == 0 && raw > 0) ||
                               (selectedIndex == maxIndex && raw < 0) {
                                dragOffset = raw / 3
                            } else {
                                dragOffset = raw
                            }
                        }
                        .onEnded { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            guard dx > dy else {
                                dragOffset = 0
                                return
                            }
                            let translation = value.translation.width
                            let predicted  = value.predictedEndTranslation.width
                            var newIndex = selectedIndex
                            let maxIndex = visibleCards.count - 1
                            if translation < -(cardStride / 4) || predicted < -(cardStride / 2) {
                                newIndex = min(selectedIndex + 1, maxIndex)
                            } else if translation > (cardStride / 4) || predicted > (cardStride / 2) {
                                newIndex = max(selectedIndex - 1, 0)
                            }
                            let peek: CGFloat = newIndex == 0 ? 0 : 28
                            selectedIndex = newIndex
                            targetOffset += dragOffset
                            dragOffset = 0
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                targetOffset = CGFloat(-newIndex) * cardStride + peek
                            }
                        }
                )

                if cards.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(visibleCards.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex
                                      ? Color.movo.accent
                                      : Color.movo.textDisabled)
                                .frame(width: 7, height: 7)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                                .onTapGesture {
                                    let peek: CGFloat = index == 0 ? 0 : 28
                                    selectedIndex = index
                                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                                        targetOffset = CGFloat(-index) * cardStride + peek
                                    }
                                }
                        }

                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 0)
                }
            }
        }
        .frame(minHeight: cards.count > 1 ? 225 : 205)
        .contentShape(Rectangle())
    }

}
