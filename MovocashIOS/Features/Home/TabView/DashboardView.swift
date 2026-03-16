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
    
    @StateObject private var vm = VCardViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager
    )
    @State private var card: VCardsResponse?
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsResponse?
    
    // MARK: - Savings
    
    @StateObject private var savingVM = SavingsAccountViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager
    )
    @State private var savingsList: SavingsAccountListResponse?
    @State private var selectedAccount: SavingsAccountDetailsResponse?
    @State private var showAccountList = false
    @State private var showPrimaryAccountDetails = false
    @State private var showAccountDetail = false
    @State private var showCreateView = false
    @State private var showEditNickname = false
    
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
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked else { return }
            await loadData()
        }
        .onAppear {
            showCardDetail = false
            showCreateView = false
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        CustomHeaderView(userName: "Test", userImage: "user") {
            AlertManager.shared.showConfirmation(
                title: "Info",
                message: "Are you want to logout.",
                onConfirm: {
                    Task {
                        AppContainer.lockManager.logout()
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
                vcardSection
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
                onCreateTap: { showCreateView = true }
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
        } else if savingVM.state == .loading {
            CardSkeletonView()
        }
    }
    
    @ViewBuilder
    private var vcardSection: some View {
        switch vm.state {
        case .loading where card == nil:
            CardSkeletonView()
        default:
            if let card {
                CustomCardView(
                    title: "MOVO.",
                    card: card,
                    vm: vm,
                    showCardDetail: $showCardDetail,
                    revealedCard: $revealedCard
                )
            }
        }
    }
    
    // MARK: - Overlay
    
    @ViewBuilder
    private var overlayContent: some View {
        if showCardDetail, let revealed = revealedCard {
            dimmedOverlay { showCardDetail = false } content: {
                VirtualCardDetailPopupView(card: revealed, isPresented: $showCardDetail)
                    .padding(.horizontal, 15)
            }
        } else if showPrimaryAccountDetails, let display = displayAccount {
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
        async let savings: () = loadSavings()
        async let vcard: () = loadCard()
        await savings
        await vcard
    }
    
    private func loadSavings() async {
        do { savingsList = try await savingVM.getSavingAccountList() } catch {}
    }
    
    private func loadCard() async {
        do { card = try await vm.getVCard() } catch {}
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
        do {
            _ = try await savingVM.createSavingAccount(
                request: SavingsAccountRequest.CreateAccount(nickname: name)
            )
            ToastManager.shared.show("\"\(name)\" account created!", style: .success, position: .bottom)
        } catch {}
        
        
        // TODO: call savingVM.createAccount(name)
        ToastManager.shared.show("\"\(name)\" account created!", style: .success, position: .bottom)
    }
}
