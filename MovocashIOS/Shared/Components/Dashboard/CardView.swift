//
//  CardVcard.swift
//  MovocashIOS
//
//  Created by Vinu on 30/04/26.
//

import Foundation
import SwiftUI

// MARK: - Card Item

struct CardItemView: View {

    let card: VCardListResponse
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.movo.accent.opacity(0.55) : Color.movo.border,
                            lineWidth: isSelected ? Stroke.thin : Stroke.hairline
                        )
                )

            VStack(alignment: .leading, spacing: 0) {

                // Icon + card name
                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                    Text((card.name ?? card.displayName).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.9)
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.movo.accent.opacity(0.7))
                    }
                }

                Spacer().frame(height: Spacing.md)

                // Balance amount
                Text(card.displayBalance)
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .tracking(-0.6)
                    .foregroundColor(Color.movo.textPrimary)

                Spacer()

                // Type · last four
                Text("VIRTUAL  ·  ••\(card.lastFour ?? "——")")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(Color.movo.textTertiary)
            }
            .padding(Spacing.lg)
        }
        .frame(height: 125)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Card Selector

struct CardSelectorView: View {

    private static let maxVisible = 5

    @State private var selectedIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var peekInset: CGFloat = 0

    let cards: [VCardListResponse]
    var sectionTitle: String = "CASH CARDS"
    var onTap: () -> Void
    var onEyeTap: ((VCardListResponse) -> Void)? = nil
    var onShowMore: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in

            let isSingle = cards.count == 1
            let cardWidth = isSingle ? geo.size.width : geo.size.width - 56
            let visibleCards = Array(cards.prefix(CardSelectorView.maxVisible))
            let hasMore = cards.count > CardSelectorView.maxVisible

            VStack(alignment: .leading, spacing: Spacing.md) {

                // Header
                HStack {
                    Text(sectionTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color.movo.textTertiary)

                    Spacer()

                    Button(action: { onTap() }) {
                        HStack(spacing: 3) {
                            Text("+")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Issue physical")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color.movo.accent)
                    }
                    .buttonStyle(.plain)
                }

                if isSingle {
                    // Single card: tap opens details directly
                    CardItemView(card: visibleCards[0], isSelected: true)
                        .frame(width: cardWidth)
                        .onTapGesture {
                            onEyeTap?(visibleCards[0])
                        }

                } else {
                    let cardStride = cardWidth + 8

                    // Offset-based carousel
                    // First tap on a card → selects it (accent border appears)
                    // Second tap on the already-selected card → opens details
                    HStack(spacing: 8) {
                        ForEach(visibleCards.indices, id: \.self) { index in
                            CardItemView(
                                card: visibleCards[index],
                                isSelected: selectedIndex == index
                            )
                            .frame(width: cardWidth)
                            .onTapGesture {
                                if selectedIndex == index {
                                    onEyeTap?(visibleCards[index])
                                } else {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                        selectedIndex = index
                                        dragOffset = 0
                                        peekInset = index == 0 ? 0 : 28
                                    }
                                }
                            }
                        }
                    }
                    .offset(x: CGFloat(-selectedIndex) * cardStride + peekInset + dragOffset)
                    .frame(height: 130, alignment: .leading)
                    .clipped()
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let dx = abs(value.translation.width)
                                let dy = abs(value.translation.height)
                                guard dx > dy else { return }
                                let raw = value.translation.width
                                if (selectedIndex == 0 && raw > 0) ||
                                   (selectedIndex == visibleCards.count - 1 && raw < 0) {
                                    dragOffset = raw / 3
                                } else {
                                    dragOffset = raw
                                }
                            }
                            .onEnded { value in
                                let dx = abs(value.translation.width)
                                let dy = abs(value.translation.height)
                                guard dx > dy else {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                        dragOffset = 0
                                    }
                                    return
                                }
                                let translation = value.translation.width
                                let predicted  = value.predictedEndTranslation.width
                                var newIndex = selectedIndex
                                if translation < -(cardStride / 4) || predicted < -(cardStride / 2) {
                                    newIndex = min(selectedIndex + 1, visibleCards.count - 1)
                                } else if translation > (cardStride / 4) || predicted > (cardStride / 2) {
                                    newIndex = max(selectedIndex - 1, 0)
                                }
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    selectedIndex = newIndex
                                    dragOffset = 0
                                    peekInset = newIndex == 0 ? 0 : 28
                                }
                            }
                    )

                    // Dot pagination + show more grouped tightly
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            ForEach(visibleCards.indices, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedIndex
                                          ? Color.movo.accent
                                          : Color.movo.textDisabled.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                            selectedIndex = index
                                            dragOffset = 0
                                            peekInset = index == 0 ? 0 : 28
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if hasMore {
                            Button { onShowMore?() } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "square.stack.3d.up")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("+\(cards.count - CardSelectorView.maxVisible) more cards")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(0.1)
                                }
                                .foregroundStyle(Color.movo.accent)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.xxl)
                                        .fill(Color.movo.accentTint)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Radius.xxl)
                                                .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: cards.count <= 1
               ? 155
               : cards.count > CardSelectorView.maxVisible ? 225 : 190)
        .clipped()
        .contentShape(Rectangle())
    }
}
