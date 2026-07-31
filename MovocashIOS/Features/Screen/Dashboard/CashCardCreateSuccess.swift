//
//  CashCardCreateSuccess.swift
//  MovocashIOS
//
//  Created by Vinu on 01/06/26.
//

import SwiftUI

struct CashCardCreateSuccess: View {
    
    let card: VCardListResponse
    
    var onDone: () -> Void = {}
    
    var onClose: (() -> Void)? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            
            Spacer().frame(height: Spacing.xxxl)
            
            CheckmarkHalo()
                .frame(width: 88, height: 88)
            
            Spacer().frame(height: Spacing.xxl)
            
            Text("Your digital cash card •••• \(card.lastFour ?? "----") is live!")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.accent)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.movo.accentTint)
                        .overlay(
                            Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                        )
                )
            
            Spacer().frame(height: Spacing.xxl)
            
            Text("Spend with it anywhere, or add it to Apple Wallet for tap-to-pay.")
                .foregroundColor(Color.movo.textTertiary)
                .textStyle(Typography.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xl)
            
            Spacer().frame(height: Spacing.xxxl)
            
            // MARK: - CTA
            
            Button(action: onDone) {
                Text("View my card")
                    .tracking(1.5)
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(
            ZStack {
                Color.movo.background
                RadialGradient(
                    colors: [
                        Color.movo.accent.opacity(0.14),
                        Color.movo.background
                    ],
                    center: UnitPoint(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet))
        .overlay(alignment: .topTrailing) {
            if let onClose {
                CircularNavButton(systemName: "xmark", action: onClose)
                    .padding(Spacing.md)
            }
        }
    }
}
