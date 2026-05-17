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
        .frame(height: 145)
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

            let cardWidth = geo.size.width - 56
            let viewAllWidth = cardWidth / 3
            let viewAllPeek = geo.size.width - viewAllWidth - Spacing.sm
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
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.movo.accent)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.movo.accentTint))
                    }
                    .buttonStyle(.plain)
                    Spacer()
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                    selectedIndex = index
                                    dragOffset = 0
                                    peekInset = index == 0 ? 0 : 28
                                }
                            }
                        }
                    }

                    if hasMore {
                        createCardSlot
                            .frame(width: viewAllWidth, height: 145)
                            .onTapGesture {
                                if selectedIndex == visibleCards.count {
                                    onShowMore?()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                        selectedIndex = visibleCards.count
                                        dragOffset = 0
                                        peekInset = viewAllPeek
                                    }
                                }
                            }
                    }
                }
                .offset(x: CGFloat(-selectedIndex) * cardStride + peekInset + dragOffset)
                .frame(height: 145, alignment: .leading)
                .clipped()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            guard dx > dy else { return }
                            let raw = value.translation.width
                            if (selectedIndex == 0 && raw > 0) ||
                               (selectedIndex == visibleCards.count && raw < 0) {
                                dragOffset = raw / 3
                            } else {
                                dragOffset = raw
                            }
                        }
                        .onEnded { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            guard dx > dy else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                    dragOffset = 0
                                }
                                return
                            }
                            let translation = value.translation.width
                            let predicted  = value.predictedEndTranslation.width
                            var newIndex = selectedIndex
                            if translation < -(cardStride / 4) || predicted < -(cardStride / 2) {
                                newIndex = min(selectedIndex + 1, visibleCards.count)
                            } else if translation > (cardStride / 4) || predicted > (cardStride / 2) {
                                newIndex = max(selectedIndex - 1, 0)
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                selectedIndex = newIndex
                                dragOffset = 0
                                peekInset = newIndex == 0 ? 0 : (newIndex == visibleCards.count ? viewAllPeek : 28)
                            }
                        }
                )

                if cards.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(visibleCards.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex
                                      ? Color.movo.accent
                                      : Color.movo.textDisabled.opacity(0.5))
                                .frame(width: 5, height: 5)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                        selectedIndex = index
                                        dragOffset = 0
                                        peekInset = index == 0 ? 0 : 28
                                    }
                                }
                        }
                        if hasMore {
                            Circle()
                                .fill(selectedIndex == visibleCards.count
                                      ? Color.movo.accent
                                      : Color.movo.textDisabled.opacity(0.5))
                                .frame(width: 5, height: 5)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                        selectedIndex = visibleCards.count
                                        dragOffset = 0
                                        peekInset = viewAllPeek
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: cards.count > 1 ? 210 : 200)
        .clipped()
        .contentShape(Rectangle())
    }

    private var createCardSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(Color.movo.elevated.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .strokeBorder(
                            Color.movo.accentBorder,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )

            VStack(spacing: Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Color.movo.elevatedHigh)
                        .frame(width: 56, height: 56)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(Color.movo.accent)
                }
                VStack(spacing: Spacing.xs) {
                    Text("View all")
                        .textStyle(Typography.cardTitle)
                        .foregroundColor(Color.movo.textPrimary)
                    Text("\(cards.count) cards")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
