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
    var onCardTap: () -> Void
    var onPrimaryTap: () -> Void
    var onViewCardTap: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            VStack(alignment: .leading, spacing: 20) {
                
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
                HStack {
                    Text(account.formattedBalance)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    
                    Spacer()
                    
                    StatusBadge(status: .cardView, size: .large, action: { onViewCardTap() })
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.secondary.opacity(0.8))
                    .onTapGesture { onCardTap() }
            )
        }
        .padding(.horizontal, 15)
    }
}
