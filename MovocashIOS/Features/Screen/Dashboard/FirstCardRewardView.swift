//
//  FirstCardRewardView.swift
//  MovocashIOS
//

import SwiftUI

struct FirstCardRewardView: View {
    
    var onViewDetails: () -> Void = {}
    
    var onClose: () -> Void = {}
    
    var body: some View {
        ZStack {
            MovoBackground()
            
            AmbientGlowView()
            
            SparkleDecorations()
            
            VStack(spacing: 0) {
                
                // Close
                HStack {
                    Spacer()
                    CircularNavButton(systemName: "xmark", action: onClose)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                Spacer()
                
                // Reward eyebrow pill
                rewardPill
                
                Spacer().frame(height: Spacing.xxl)
                
                Text("Your first card is on us.")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.huge)
                
                Spacer().frame(height: Spacing.lg)
                
                Text("A free virtual MOVOCASH card, ready to use right now. Add it to Apple Pay in one tap.")
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.huge)
                
                Spacer()
                
                Button(action: onViewDetails) {
                    Text("Let's MOVO")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
        }
    }
    
    // MARK: - Reward Pill
    
    private var rewardPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("REWARD UNLOCKED")
                .textStyle(Typography.eyebrow)
        }
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
    }
}
