//
//  SavingActDetailPopupView.swift
//  MovocashIOS
//
//  Created by Vinu on 13/03/26.
//

import SwiftUI

struct SavingActDetailPopupView: View {
    
    let account: SavingsAccountDetailsResponse
    @Binding var isPresented: Bool
    @State private var copiedField: String?
    
    var body: some View {
        BasePopupView(
            maskedNumber: account.nickname ?? "-----",
            formattedBalance: account.formattedBalance,
            balanceLabel: "AVAILABLE BALANCE",
            isPresented: $isPresented
        ) {
            DetailField(
                label: "ACCOUNT NUMBER",
                value: account.accountNumber,
                copiedField: $copiedField,
                fullWidth: true,
                accentColor: AppColors.primary
            )
            
            Divider().padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 0) {
                PlainField(
                    label: "STATUS",
                    value: account.status.displayTitle,
                    fullWidth: true
                )
                
                Divider().frame(height: 60)
                
                PlainField(
                    label: "PRIMARY",
                    value: account.isPrimary ? "Yes" : "No",
                    fullWidth: true
                )
            }
        }
    }
}
