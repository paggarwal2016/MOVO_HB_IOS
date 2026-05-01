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

            // 🔥 Premium Black Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color(red: 0.08, green: 0.08, blue: 0.08),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // ✨ Subtle top light reflection
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    // 🎯 Premium border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected
                            ? Color.white.opacity(0.6)
                            : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )

            // 🧾 Card Content
            VStack(alignment: .leading, spacing: 16) {

                // Balance
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)

                    Text(card.displayBalance)
                        .foregroundColor(.white)
                        .font(.title3)
                        .bold()
                }

                // Card Number + Eye
                HStack(spacing: 8) {
                    Text(card.maskedNumber)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Button {
                        onEyeTap?(card)
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Expiry + Name + Network
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.formattedExpiry)
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)

                        Text(card.displayName)
                            .foregroundColor(.white)
                            .font(.caption)
                    }

                    Spacer()

                    // Replace with Image if needed
                    Text("Mastercard")
                        .foregroundColor(.white)
                        .font(.headline)
                        .bold()
                        .padding(.top, 17)
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
            let cardWidth = isSingle ? geo.size.width : geo.size.width - 35

            VStack(alignment: .leading) {

                HStack {
                    Text(sectionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    Button(action: { onTap() }) {
                        Text("Add new +")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
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
                            HStack(spacing: 8) {
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
        .frame(height: cards.count <= 1 ? 220 : cards.count > CardSelectorView.maxVisible ? 265 : 245)
    }
}
