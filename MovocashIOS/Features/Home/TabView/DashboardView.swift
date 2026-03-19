//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    
    // MARK: - Environment
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var sessionManager: SessionManager
    
    // MARK: - VCard

    @StateObject private var vm: VCardViewModel

    // MARK: - Savings

    @StateObject private var savingVM: SavingsAccountViewModel

    // MARK: - Init

    init(
        vm: VCardViewModel = AppContainer.shared.makeVCardViewModel(),
        savingVM: SavingsAccountViewModel = AppContainer.shared.makeSavingsAccountViewModel()
    ) {
        _vm = StateObject(wrappedValue: vm)
        _savingVM = StateObject(wrappedValue: savingVM)
    }
    @State private var savingsList: SavingsAccountListResponse?
    @State private var selectedAccount: SavingsAccountDetailsResponse?
    @State private var showAccountList = false
    @State private var showPrimaryAccountDetails = false
    @State private var showAccountDetail = false
    @State private var showCreateView = false
    @State private var showEditNickname = false
    
    @State private var showViewCard = false
    @State private var showFunds = false
    
    private var displayAccount: SavingsAccountDetailsResponse? {
        selectedAccount ?? savingsList?.accounts.first(where: { $0.isPrimary })
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                scrollContent
            }
        }
        .overlay { overlayContent }
        .textInputAlert(
            isPresented: $showCreateView,
            title: "New Account",
            message: "Enter a name for your new savings account.",
            placeholder: "Type here...",
            onCreate: { name in
                Task { await createAccount(name: name) }
            }
        )
        .textInputAlert(
            isPresented: $showEditNickname,
            title: "Edit Nickname",
            message: "Enter a new nickname for your savings account.",
            placeholder: "Type here...",
            config: TextInputAlertConfig(primaryLabel: "Save"),
            onCreate: { name in
                Task { await updateNickname(name: name) }
            }
        )
        .overlay {
            if savingVM.state == .loading {
                SpinnerView()
            }
        }
        .sheet(isPresented: $showAccountDetail) {
            if let account = displayAccount {
                SavingAccountDetailView(accountId: account.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAccountList) {
            AccountListSheetView(selectedAccount: $selectedAccount, isPresented: $showAccountList)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showViewCard) {
            ViewCardScreen(isPresented: $showViewCard)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFunds) {
            InternalTransferView(
                toClientId: displayAccount?.clientId ?? 0,
                fromAccount: savingsList?.accounts.first(where: { $0.isPrimary }),
                nonPrimaryAccounts: savingsList?.accounts.filter({ !$0.isPrimary }) ?? []
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked else { return }
            await loadData()
        }
        .onAppear {
            showCreateView = false
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        CustomHeaderView(userName: "Test", userImage: "user") {
            AlertManager.shared.showConfirmation(
                title: "Log Out",
                message: "Are you sure you want to log out?",
                onConfirm: {
                    Task {
                        AppContainer.shared.lockManager.logout()
                        await sessionManager.logout(appState: appState)
                    }
                }
            )
        }
    }
    
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                savingsSection
                Spacer()
            }
            .padding(.top, 16)
        }
    }
    
    @ViewBuilder
    private var savingsSection: some View {
        if let account = displayAccount {
            BalanceCardView(
                account: account,
                totalAvailableBalance: savingsList?.totalAvailableBalance ?? 0.00,
                onCardTap: { showAccountDetail = true },
                onPrimaryTap: { showPrimaryAccountDetails = true },
                onCreateTap: { showCreateView = true },
                onViewCardTap: { showViewCard = true }
            )
            PrimaryButton(
                title: "View Cash Accounts",
                backgroundColor: .gray.opacity(0.1),
                textColor: .black
            ) {
                showAccountList = true
            }
            .padding()
            .frame(height: 60)
            
            PrimaryButton(
                title: "Funds Transfer",
                backgroundColor: .red.opacity(0.1),
                textColor: .black
            ) {
                showFunds = true
            }
            .padding()
            .frame(height: 60)
        } else if savingVM.state == .loading {
            CardSkeletonView()
        }
    }
    
    
    // MARK: - Overlay
    
    @ViewBuilder
    private var overlayContent: some View {
        if showPrimaryAccountDetails, let display = displayAccount {
            dimmedOverlay { showPrimaryAccountDetails = false } content: {
                SavingActDetailPopupView(
                    account: display,
                    isPresented: $showPrimaryAccountDetails,
                    showEditNickname: $showEditNickname
                )
                .padding(.horizontal, 15)
            }
        }
        
    }
    
    @ViewBuilder
    private func dimmedOverlay(onDismiss: @escaping () -> Void, content: () -> some View) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    // MARK: - Private Functions
    
    private func loadData() async {
        await loadSavings()
    }

    private func loadSavings() async {
        savingsList = try? await savingVM.getSavingAccountList()
    }
    
    private func updateNickname(name: String) async {
        guard let account = displayAccount else { return }
        do {
            _ = try await savingVM.updateSavingAccount(
                request: SavingsAccountRequest.UpdateAccount(nickname: name, accountId: account.id)
            )
            await loadSavings()
            ToastManager.shared.show("Nickname updated!", style: .success, position: .bottom)
        } catch {
            ToastManager.shared.show("Failed to update nickname.", style: .error, position: .bottom)
        }
    }

    private func createAccount(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            ToastManager.shared.show("Account name cannot be empty.", style: .error, position: .bottom)
            return
        }
        do {
            _ = try await savingVM.createSavingAccount(
                request: SavingsAccountRequest.CreateAccount(nickname: trimmed)
            )
            await loadSavings()
            ToastManager.shared.show("\"\(trimmed)\" account created!", style: .success, position: .bottom)
        } catch {
            ToastManager.shared.show("Failed to create account. Please try again.", style: .error, position: .bottom)
        }
    }
}
