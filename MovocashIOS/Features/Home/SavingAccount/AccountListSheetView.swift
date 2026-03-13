//
//  AccountListSheetView.swift
//  MovocashIOS
//
//  Created by Vinu on 13/03/26.
//

import SwiftUI

struct AccountListSheetView: View {
    
    @Binding var selectedAccount: SavingsAccountDetailsResponse?
    @Binding var isPresented: Bool
    
    @StateObject private var savingVM = SavingsAccountViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager
    )
    
    @State private var accounts: [SavingsAccountDetailsResponse] = []
    
    var body: some View {
        NavigationStack {
            Group {
                switch savingVM.state {
                case .loading:
                    loadingView
                default:
                    accountList
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(AppColors.primary)
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await loadAccounts() }
    }
    
    private var accountList: some View {
        List(accounts, id: \.id) { account in
            AccountRowView(
                account: account,
                isSelected: selectedAccount?.id == account.id
            )
            .contentShape(Rectangle())
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.systemGroupedBackground))
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                CardSkeletonView()
            }
            Spacer()
        }
        .padding(.top, 16)
    }
    
    private func loadAccounts() async {
        do {
            let response = try await savingVM.getSavingAccountList()
            accounts = response.accounts.filter { !$0.isPrimary }
        } catch {}
    }
}


// MARK: - Account Row

struct AccountRowView: View {
    
    let account: SavingsAccountDetailsResponse
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: - Icon
            
            Image(systemName: "banknote")
                .font(.title2)
                .foregroundStyle(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // MARK: - Info
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.nickname ?? "-----")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(account.accountNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // MARK: - Checkmark
            
            let formatted = String(format: "%.2f", NSDecimalNumber(decimal: account.availableBalance).doubleValue)
            
            Text(formatted)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
