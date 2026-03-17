//
//  BalanceCardView.swift
//  MovocashIOS
//
//  Created by Vinu on 13/03/26.
//

import Foundation
import SwiftUI

struct BalanceCardView: View {
    
    // MARK: - Properties
    
    let account: SavingsAccountDetailsResponse
    var totalAvailableBalance: Decimal
    var onCardTap: () -> Void
    var onPrimaryTap: () -> Void
    var onCreateTap: () -> Void
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
                .fill(AppColors.secondary)
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
                                Text("Primary")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Capsule())
                                    .onTapGesture { onPrimaryTap() }
                            }
                            
                            if account.status.rawValue == "Active" {
                                Text(account.status.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            
                            Text("View")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.3))
                                .clipShape(Capsule())
                            
                            Spacer()
                            
                            // MARK: + Create Button
                            Button(action: onCreateTap) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                            .buttonStyle(.plain)
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
                            
                            Button(action: {
                                onViewCardTap()
                            }) {
                                Text("View Card")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 90, height: 30)
                                    .background(.blue.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 18)
                }
        }
        .padding(.horizontal, 15)
    }
}
