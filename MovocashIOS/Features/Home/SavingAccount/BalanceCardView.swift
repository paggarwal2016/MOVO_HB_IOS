//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import SwiftUI

struct BalanceCardView: View {
    
    let account: SavingsAccountInfo
    var showViewCard: Bool
    var onCardTap: () -> Void
    var onPrimaryTap: () -> Void
    var onViewCardTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
                .contentShape(Rectangle())
                .onTapGesture { onCardTap() }
            
            VStack(alignment: .leading, spacing: 0) {
                
                // Eyebrow label + edit nickname
                HStack(spacing: 6) {
                    Text("AVAILABLE BALANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color.movo.textTertiary)
                }
                
                Spacer().frame(height: Spacing.sm)
                
                // Balance amount
                Text("$\(account.availableBalance.toCurrencyString())")
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .tracking(-1.0)
                    .foregroundColor(Color.movo.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                Spacer().frame(height: Spacing.sm)
                
                StatusPill(
                    account.status == .active ? "Active" : account.status.rawValue,
                    variant: account.status == .active ? .accent : .neutral
                )
                
                Spacer()
                
                // Bottom row: account info + brand
                HStack(alignment: .bottom) {
                    HStack(spacing: 4) {
                        Text("\(account.isPrimary ? "PRIMARY" : "ACCOUNT")  ·  ••\(account.accountNumber.suffix(4))")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(Color.movo.textTertiary)
                        Button(action: onPrimaryTap) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.movo.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    if showViewCard {
                        Button(action: onViewCardTap) {
                            HStack(spacing: 4) {
                                Text("View Card")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(0.3)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(Color.movo.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .frame(height: 160)
        .padding(.horizontal, Spacing.lg)
    }
}
