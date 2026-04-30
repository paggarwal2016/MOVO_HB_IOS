//
//  CardVcard.swift
//  MovocashIOS
//
//  Created by Vinu on 30/04/26.
//

import Foundation
import SwiftUI

struct CardItemView: View {

    let card: VCardListResponse
    let isSelected: Bool
    var onEyeTap: ((VCardListResponse) -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5).opacity(0.15),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? .primary : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .foregroundColor(.white)
                        .font(.caption)

                    Text(card.displayBalance)
                        .foregroundColor(.white)
                        .font(.title3)
                        .bold()
                }

                HStack(spacing: 8) {
                    Text(card.maskedNumber)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button { onEyeTap?(card) } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.formattedExpiry)
                            .foregroundColor(.white)
                            .font(.caption)

                        Text(card.displayName)
                            .foregroundColor(.white)
                            .font(.caption)
                    }

                    Spacer()

                    Text("VISA")
                        .foregroundColor(.white)
                        .font(.headline)
                        .bold()
                }
            }
            .padding()
        }
        .frame(height: 170)
    }
}


struct CardSelectorView: View {

    private static let maxVisible = 5

    @State private var selectedIndex: Int = 0
    let cards: [VCardListResponse]
    var sectionTitle: String = "My Cards"
    var onTap: () -> Void
    var onEyeTap: ((VCardListResponse) -> Void)? = nil
    var onShowMore: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in

            let isSingle = cards.count == 1
            let cardWidth = isSingle ? geo.size.width : geo.size.width * 0.8

            VStack(alignment: .leading) {

                HStack {
                    Text(sectionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    Button(action: { onTap() }) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 36, height: 36)

                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 2)

                let visibleCards = Array(cards.prefix(CardSelectorView.maxVisible))
                let hasMore = cards.count > CardSelectorView.maxVisible

                if isSingle {
                    CardItemView(card: visibleCards[0], isSelected: false, onEyeTap: onEyeTap)
                        .frame(width: cardWidth)

                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(visibleCards.indices, id: \.self) { index in
                                    CardItemView(
                                        card: visibleCards[index],
                                        isSelected: selectedIndex == index,
                                        onEyeTap: onEyeTap
                                    )
                                    .frame(width: cardWidth)
                                    .id(index)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            selectedIndex = index
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            ForEach(visibleCards.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == selectedIndex ? .primary : Color.gray.opacity(0.3))
                                    .frame(width: index == selectedIndex ? 18 : 6, height: 6)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            selectedIndex = index
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                    }

                    if hasMore {
                        Button { onShowMore?() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secTcolor)
                                Text("Show more")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secTcolor)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: cards.count <= 1 ? 220 : cards.count > CardSelectorView.maxVisible ? 280 : 245)
    }
}
