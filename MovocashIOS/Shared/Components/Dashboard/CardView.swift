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
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                )

            VStack(alignment: .leading, spacing: 0) {
                
                // Icon + card name
                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.movo.textTertiary)
                    Text((card.savingsAccountNickname ?? card.name ?? card.displayName).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.9)
                        .foregroundColor(Color.movo.textTertiary)
                    Spacer()
                }
                
                Spacer().frame(height: Spacing.md)
                
                // Balance amount
                Text(card.displayBalance)
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .tracking(-0.6)
                    .foregroundColor(Color.movo.textPrimary)
                
                Spacer()
                
                // Type · masked number
                Text("VIRTUAL  ·  \(card.maskedNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(Color.movo.textTertiary)
            }
            .padding(Spacing.lg)
        }
        .frame(height: 145)
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

            let cardWidth = geo.size.width - 56
            let cardStride = cardWidth + 8
            let visibleCards = Array(cards.prefix(CardSelectorView.maxVisible))
            let hasMore = cards.count > CardSelectorView.maxVisible

            VStack(alignment: .leading, spacing: Spacing.md) {

                // Header
                HStack {
                    Text(sectionTitle.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color.movo.textTertiary)

                    Button(action: onTap) {
                        CircleIconAvatar(systemName: "plus", size: 24, tint: .accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if hasMore {
                        Button(action: { onShowMore?() }) {
                            Eyebrow("SEE ALL (\(cards.count))")
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Carousel: existing cards + create card slot at end
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
                                let peek: CGFloat = index == 0 ? 0 : 28
                                selectedIndex = index
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                    targetOffset = CGFloat(-index) * cardStride + peek
                                }
                            }
                        }
                    }


                }
                .offset(x: targetOffset + dragOffset)
                .frame(height: 145, alignment: .leading)
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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
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
        .frame(height: cards.count > 1 ? 205 : 190)
        .clipped()
        .contentShape(Rectangle())
    }

}
