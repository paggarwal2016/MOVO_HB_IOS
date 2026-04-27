//
//  CustomCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import UIKit
import SwiftUI

struct CustomCardView: View {
    
    let title: String
    let card: VCardsList
    @StateObject private var vm: VCardViewModel
    @Binding var showCardDetail: Bool
    @Binding var revealedCard: VCardsList?
    @State private var isRevealing = false

    init(title: String,
         card: VCardsList,
         vm: VCardViewModel,
         showCardDetail: Binding<Bool>,
         revealedCard: Binding<VCardsList?>) {
        self.title = title
        self.card  = card
        _vm              = StateObject(wrappedValue: vm)
        _showCardDetail  = showCardDetail
        _revealedCard    = revealedCard
    }
    
    var body: some View {
        ZStack {
            cardBackground
            cardContent
        }
        .frame(height: 180)
        .padding(.horizontal)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.black)
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Image("mastercard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48)
            }
            
            Spacer()
            
            Text(card.firstName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.5)
            
            Spacer().frame(height: 8)
            
            HStack(alignment: .center, spacing: 12) {
                Text(card.cardNumber.maskedCardNumber())
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                
                eyeButton
                Spacer()
            }
        }
        .padding(15)
    }
    
    private var eyeButton: some View {
        Button {
            Task { await revealCard() }
        } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                if isRevealing {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image("invisible")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
        }
        .disabled(isRevealing)
    }
    
    private func revealCard() async {
        isRevealing = true
        defer { isRevealing = false }
        do {
            revealedCard = try await vm.getVCardPrimary()?.data
            showCardDetail = true
        } catch {
            ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
        }
    }
}
