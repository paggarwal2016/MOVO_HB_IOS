//
//  SavingActDetailPopupView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

struct SavingActDetailPopupView: View {

    let account: SavingsAccountDetailsResponse
    @Binding var isPresented: Bool
    @Binding var showEditNickname: Bool

    @State private var copiedField: String?

    var body: some View {
        BasePopupView(
            nickName: account.nickname ?? "",
            formattedBalance: account.formattedBalance,
            balanceLabel: "AVAILABLE BALANCE",
            isPresented: $isPresented,
            headerTrailing: { editButton }   // ← pass edit button into header
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
                PlainField(label: "STATUS",  value: account.status.displayTitle, fullWidth: true)
                Divider().frame(height: 60)
                PlainField(label: "PRIMARY", value: account.isPrimary ? "Yes" : "No", fullWidth: true)
            }
        }
    }

    // MARK: - Edit Button (injected into BasePopupView header)

    private var editButton: some View {
        Button {
            showEditNickname = true
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(.white.opacity(0.25))
                .clipShape(Circle())
        }
    }



}
