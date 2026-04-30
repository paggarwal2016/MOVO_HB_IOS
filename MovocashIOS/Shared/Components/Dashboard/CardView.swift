//
//  CardVcard.swift
//  MovocashIOS
//
//  Created by Vinu on 30/04/26.
//

import Foundation
import SwiftUI

struct CardItemView: View {
    
    let card: CardUIModel
    let isSelected: Bool
    let showSelection: Bool
    var onSelect: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            
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
                        .stroke(
                            showSelection && isSelected
                            ? Color.primary
                            : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Text(card.balanceText)
                        .foregroundColor(.white)
                        .font(.title3)
                        .bold()
                }
                
                Text(maskedNumber(card.cardNumber))
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.expiry)
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Text(card.holderName)
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(card.brand)
                        .foregroundColor(.white)
                        .font(.headline)
                        .bold()
                }
            }
            .padding()
            
            // Radio → tick: circle by default, checkmark.circle.fill when selected
            if showSelection {
                Button { onSelect?() } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .primary : .white.opacity(0.6))
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 170)
    }
    
    private func maskedNumber(_ number: String) -> String {
        "••••  ••••  ••••  \(number.suffix(4))"
    }
}


struct CardSelectorView: View {

    @State private var selectedIndex: Int = 0
    let cards: [CardUIModel]
    var sectionTitle: String = "My Cards"
    var onTap: () -> Void
    
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
                    
                    Button(action: {
                        onTap()
                    }) {
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
                
                if isSingle {
                    
                    // ✅ SINGLE CARD (FULL WIDTH)
                    CardItemView(
                        card: cards[0],
                        isSelected: false,
                        showSelection: false
                    )
                    .frame(width: cardWidth)
                    
                } else {

                    // ✅ MULTIPLE CARDS (SCROLL + bring selected to front)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(cards.indices, id: \.self) { index in
                                    CardItemView(
                                        card: cards[index],
                                        isSelected: selectedIndex == index,
                                        showSelection: true,
                                        onSelect: {
                                            withAnimation(.spring()) {
                                                selectedIndex = index
                                                proxy.scrollTo(index, anchor: .center)
                                            }
                                        }
                                    )
                                    .frame(width: cardWidth)
                                    .id(index)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ✅ Pagination (ONLY for multiple)
                    HStack(spacing: 6) {
                        ForEach(cards.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? .primary : Color.gray.opacity(0.3))
                                .frame(width: index == selectedIndex ? 18 : 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 5)
                }
            }
        }
        .frame(height: 220)
    }
}
