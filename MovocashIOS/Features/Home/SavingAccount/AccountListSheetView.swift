//
//  AccountListSheetView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import SwiftUI

struct AccountListSheetView: View {
    
    @Binding var savingsList: SavingsAccountListResponse?
    @Binding var isPresented: Bool
    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var vcardVM: VCardViewModel

    private let container: AppContainer

    init(
        savingsList: Binding<SavingsAccountListResponse?>,
        isPresented: Binding<Bool>,
        container: AppContainer
    ) {
        _savingsList = savingsList
        _isPresented = isPresented
        self.container = container
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _vcardVM = StateObject(wrappedValue: container.makeVCardViewModel())
    }

    @State private var accounts: [SavingsAccountDetailsResponse] = []
    @State private var primaryAccountId: Int?
    @State private var selectedDetailAccount: SavingsAccountDetailsResponse?

    @State private var showCreateCashCard = false
    @State private var showEditNickname = false
    @State private var accountToEdit: SavingsAccountInfo?
    
    @State private var sortBy: SavingsSortBy = .id
    @State private var sortDirection: SavingsSortDirection = .asc
    
    var body: some View {
        ZStack {
            NavigationStack {
                accountList
                    .navigationTitle("Cash Cards")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showCreateCashCard = true
                            } label: {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isPresented = false }
                                .foregroundStyle(Color.primary)
                                .fontWeight(.semibold)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            sortMenuButton
                        }
                    }
            }
            
            if savingVM.state == .loading && !accounts.isEmpty && !showCreateCashCard {
                SpinnerView()
            }
        }
        .sheet(isPresented: $showCreateCashCard) {
            CreateCashCardView(
                onCancel: { showCreateCashCard = false },
                onCreate: { nickname, pin in
                    await createCashCard(nickname: nickname, pin: pin)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .textInputAlert(
            isPresented: $showEditNickname,
            title: "Edit Nickname",
            message: "Enter a new nickname for this account.",
            placeholder: "Type here...",
            config: TextInputAlertConfig(primaryLabel: "Save"),
            onCreate: { name in
                Task { await updateNickname(name: name) }
            }
        )
        .sheet(item: $selectedDetailAccount) { account in
            SavingAccountDetailView(accountId: account.id, container: container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .globalAlert()
        .task { await loadAccounts() }
        .onChange(of: sortBy) { _ in Task { await loadAccounts() } }
        .onChange(of: sortDirection) { _ in Task { await loadAccounts() } }
    }
    
    // MARK: - Sort Direction Toggle
    
    private var sortMenuButton: some View {
        Button {
            sortDirection = sortDirection == .asc ? .desc : .asc
        } label: {
            Image(systemName: sortDirection == .asc ? "arrow.up" : "arrow.down")
                .foregroundStyle(Color.primary)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Account List
    
    private var accountList: some View {
        List {
            if savingVM.state == .loading && accounts.isEmpty {
                // First-time load — show skeleton placeholders
                ForEach(0..<4, id: \.self) { _ in
                    AccountRowSkeleton()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowInsets(EdgeInsets())
                }
            } else {
                ForEach(accounts, id: \.id) { account in
                    AccountRowView(account: account)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedDetailAccount = account }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowInsets(EdgeInsets())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                confirmDelete(account: account)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color.primary)
                            
                            Button {
                                accountToEdit = account
                                showEditNickname = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.secondary)
                        }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Load
    
    private func loadAccounts() async {
        do {
            let response = try await savingVM.getSavingAccountList(sortBy: sortBy, sortDirection: sortDirection)
            savingsList = response
            accounts = response.data.accounts.filter { !$0.isPrimary }
            primaryAccountId = response.data.accounts.first(where: { $0.isPrimary })?.id
            if accounts.count == 0 { isPresented = false }
        } catch {
            ToastManager.shared.show("Failed to load accounts.", style: .error, position: .bottom)
        }
    }
    
    // Fires a silent background sync without blocking the caller
    private func backgroundSync() {
        Task { await loadAccounts() }
    }
    
    // MARK: - Create

    private func createCashCard(nickname: String, pin: String) async {
        do {
            let newAccount = try await savingVM.createSavingAccount(
                request: SavingsAccountRequest.CreateAccount(nickname: nickname)
            )
            _ = try await vcardVM.postVCard(
                request: VCardsRequest(pin: pin, accountId: newAccount.id)
            )
            accounts.append(newAccount)
            showCreateCashCard = false
            ToastManager.shared.show("Cash card \"\(nickname)\" created!", style: .success, position: .bottom)
            backgroundSync()
        } catch {
            ToastManager.shared.show("Failed to create cash card. Please try again.", style: .error, position: .bottom)
        }
    }
    
    // MARK: - Update Nickname
    
    private func updateNickname(name: String) async {
        guard let account = accountToEdit else { return }
        accountToEdit = nil
        do {
            _ = try await savingVM.updateSavingAccount(
                request: SavingsAccountRequest.UpdateAccount(nickname: name, accountId: account.id)
            )
            ToastManager.shared.show("Nickname updated!", style: .success, position: .bottom)
            backgroundSync()                                   // silent server sync
        } catch {
            ToastManager.shared.show("Failed to update nickname.", style: .error, position: .bottom)
        }
    }
    
    // MARK: - Delete
    
    private func confirmDelete(account: SavingsAccountInfo) {
        AlertManager.shared.showConfirmation(
            title: "Delete Account",
            message: "Are you sure you want to delete \"\(account.nickname ?? account.maskedAccountNumber) Account\"?",
            onConfirm: {
                Task { await deleteAccount(account) }
            }
        )
    }
    
    private func deleteAccount(_ account: SavingsAccountInfo) async {
        guard let primaryId = primaryAccountId else {
            ToastManager.shared.show("Cannot delete account: primary account not loaded.", style: .error, position: .bottom)
            return
        }
        do {
            _ = try await savingVM.deleteSavingAccount(
                request: SavingsAccountRequest.DeleteAccount(
                    targetAccountId: primaryId,
                    accountId: account.id
                )
            )
            accounts.removeAll { $0.id == account.id }         // instant UI update
            ToastManager.shared.show("Account deleted.", style: .success, position: .bottom)
            backgroundSync()                                   // silent server sync
        } catch {
            ToastManager.shared.show("Failed to delete account.", style: .error, position: .bottom)
        }
    }
}


// MARK: - Account Row

struct AccountRowView: View {
    
    let account: SavingsAccountInfo
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: - Icon
            
            Image(systemName: "banknote")
                .font(.title2)
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.1))
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
            
            // MARK: - Balance
            
            let formatted = String(format: "%.2f", NSDecimalNumber(decimal: account.availableBalance).doubleValue)
            
            Text(formatted)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
