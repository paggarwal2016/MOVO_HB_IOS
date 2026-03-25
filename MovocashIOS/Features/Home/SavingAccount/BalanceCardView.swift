//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import SwiftUI

struct BalanceCardView: View {
    
    // MARK: - Properties
    
    let account: SavingsAccountDetailsResponse
    var totalAvailableBalance: Decimal
    var onCardTap: () -> Void
    var onPrimaryTap: () -> Void
    var onViewCardTap: () -> Void
    
    // MARK: - Computed
    
    private var balanceParts: (whole: String, cents: String) {
        let formatted = String(format: "%.2f", NSDecimalNumber(decimal: totalAvailableBalance).doubleValue)
        let parts = formatted.split(separator: ".")
        return (
            whole: String(parts.first ?? "0"),
            cents: String(parts.last ?? "00")
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            // MARK: Card Background
            RoundedRectangle(cornerRadius: 15)
                .fill(AppColors.secondary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .onTapGesture { onCardTap() }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        
                        // MARK: Account Info
                        HStack(spacing: 6) {
                            Text(account.nickname ?? "Primary Account")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.black.opacity(0.6))
                            
                            if account.isPrimary {
                                StatusBadge(status: .cardPrimary, action: { onPrimaryTap() })
                            }
                            
                            if account.status.rawValue == "Active" {
                                StatusBadge(status: .cardActive)
                            }
                            
                            Spacer()
                        }
                        
                        // MARK: Balance
                        HStack(alignment: .lastTextBaseline, spacing: 1) {
                            Text("$")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.black)
                            Text(balanceParts.whole)
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.black)
                            Text(".\(balanceParts.cents)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.black)
                            
                            Spacer()
                            
                            StatusBadge(status: .cardView, size: .large, action: { onViewCardTap() } )
                            
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 18)
                }
        }
        .padding(.horizontal, 15)
    }
}
