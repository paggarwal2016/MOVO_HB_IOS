//
//  CardVcard.swift
//  MovocashIOS
//
//  Created by Movo Developer on 30/04/26.
//

import Foundation
import SwiftUI

// MARK: - Card Item

struct CardItemView: View {

    let card: VCardListResponse
    let isSelected: Bool
    /// Wired to the pre-existing card-detail handler in CardSelectorView / DashboardView.
    /// Nil-safe — nothing breaks if no handler is provided.
    var onDetail: (() -> Void)? = nil

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
                    .frame(maxHeight: .infinity)
                linkRow
            }
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(DesignTokens.Palette.silverTint.color.opacity(0.35), lineWidth: Stroke.hairline)
        )
    }

    // MARK: - Face content (data only — no background)

    private var faceContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top row: small M mark + card name + Virtual pill
            HStack(spacing: Spacing.xs) {
            Image("herringLogo").resizable().scaledToFit()
                    .frame(width: 19, height: 19)
                Text(cardName)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.9)
                    .foregroundColor(Color.movo.textPrimary)
                    .lineLimit(1)
                Spacer()
                virtualPill
            }

            Spacer()

            // Balance — tight, cents de-emphasised
            styledBalance

            Spacer().frame(height: Spacing.sm)

            // Footer: masked number — silver neutral
            Text(card.maskedNumber)
                .font(.system(size: 15, weight: .medium))
                .tracking(0.7)
                .foregroundColor(DesignTokens.Palette.silverTint.color)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    /// Tight balance display: full-weight dollars + de-emphasised cents.
    /// Falls back to a single Text if the value has no decimal point.
    @ViewBuilder
    private var styledBalance: some View {
        let raw = card.displayBalance
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        if let dotIdx = raw.lastIndex(of: ".") {
            let dollars = String(raw[raw.startIndex...dotIdx])
            let cents   = String(raw[raw.index(after: dotIdx)...])
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(dollars)
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
                    .tracking(-0.5)
                    .foregroundColor(Color.movo.textPrimary)
                Text(cents)
                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary)
            }
        } else {
            Text(raw)
                .font(.system(size: 38, weight: .bold).monospacedDigit())
                .tracking(-0.5)
                .foregroundColor(Color.movo.textPrimary)
        }
    }

    // MARK: - Virtual pill

    private var virtualPill: some View {
        MovoTypeBadge("VIRTUAL")
    }

    // MARK: - Link row

    /// Full-width tappable row. Fires the pre-existing card-detail handler.
    private var linkRow: some View {
        HStack(spacing: Spacing.xs) {
            Text("LET'S MOVO")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.accent)
            Spacer()
            MovoChevron(.cta)
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
                .frame(height: 165, alignment: .leading)
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
        .frame(height: cards.count > 1 ? 225 : 205)
        .clipped()
        .contentShape(Rectangle())
    }

}
