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
    @EnvironmentObject var userVM: UserViewModel
    @EnvironmentObject var authVM: AuthViewModel

    // MARK: - VCard

    @StateObject private var vm: VCardViewModel

    // MARK: - Savings

    @StateObject private var savingVM: SavingsAccountViewModel
    
    @StateObject private var achVM: PlaidAchViewModel

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: container.makeVCardViewModel())
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }
    @State private var showAccountList = false
    @State private var showPrimaryAccountDetails = false
    @State private var showAccountDetail = false
    @State private var showCreateView = false
    @State private var showEditNickname = false
    
    @State private var showViewCard = false
    @State private var showFunds = false

    @State private var showMoveMoney = false
    @State private var showFundAccount = false

    @State private var showContactList = false
    
    private var displayAccount: SavingsAccountDetailsResponse? {
        savingVM.accountList?.accounts.first(where: { $0.isPrimary })
    }
    
    private var isViewCashAccount: Bool {
        savingVM.accountList?.accounts.contains(where: { !$0.isPrimary }) ?? false
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
            title: "Create Cash Card",
            message: "Enter a name for your new cash card account.",
            placeholder: "Type here...",
            onCreate: { name in
                Task { await savingVM.createAccount(name: name) }
            }
        )
        .textInputAlert(
            isPresented: $showEditNickname,
            title: "Edit Nickname",
            message: "Enter a new nickname for your savings account.",
            placeholder: "Type here...",
            config: TextInputAlertConfig(primaryLabel: "Save"),
            onCreate: { name in
                guard let accountId = displayAccount?.id else { return }
                Task { await savingVM.updateNickname(name: name, accountId: accountId) }
            }
        )
        .overlay {
            if savingVM.state == .loading {
                SpinnerView()
            }
        }
        .sheet(isPresented: $showAccountDetail) {
            if let account = displayAccount {
                SavingAccountDetailView(accountId: account.id, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAccountList) {
            AccountListSheetView(isPresented: $showAccountList, container: container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showViewCard) {
            if let account = displayAccount {
                ViewCardScreen(isPresented: $showViewCard, accountId: account.id, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showFunds) {
            if let account = displayAccount {
                InternalTransferView(
                    toClientId: account.clientId,
                    fromAccount: account,
                    nonPrimaryAccounts: savingVM.accountList?.accounts.filter({ !$0.isPrimary }) ?? [],
                    container: container,
                    onDismiss: {
                        Task { await loadData() }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showContactList) {
            ContactView(isPresented: $showContactList)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFundAccount) {
            if let account = displayAccount {
                FundAccountView(container: container, primaryAccount: account) {
                    Task { await achVM.startPlaidLink() }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showMoveMoney) {
            MoveMoneyMenuView(
                onFundAccount: {
                    showMoveMoney = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showFundAccount = true
                    }
                },
                onTransferMoney: {
                    showMoveMoney = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showContactList = true
                    }
                }
            )
        }
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked, appState.isAuthenticated else { return }
            await handleOnTask()
        }
        .onAppear {
            showCreateView = false
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        CustomHeaderView(userName: userVM.profile?.initials ?? "", userImage: userVM.profile?.profilePicture ?? "") {
            sessionManager.logoutWithConfirmation(appState: appState) {
                lockManager.logout()
            }
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
                onCardTap: { showAccountDetail = true },
                onPrimaryTap: { showPrimaryAccountDetails = true },
                onViewCardTap: { showViewCard = true }
            )
            
            PrimaryButton(
                title: "Create Cash Card",
                backgroundColor: Color.softBlue.opacity(0.1),
                textColor: .black
            ) {
                showCreateView = true
            }
            .padding()
            .frame(height: 60)
            
            if isViewCashAccount {
                PrimaryButton(
                    title: "View Cash Cards",
                    backgroundColor: .gray.opacity(0.1),
                    textColor: .black
                ) {
                    showAccountList = true
                }
                .padding()
                .frame(height: 60)
            }
            
            PrimaryButton(
                title: "Move Money",
                backgroundColor: .red.opacity(0.1),
                textColor: .black
            ) {
                showMoveMoney = true
            }
            .padding()
            .frame(height: 60)
                        
            ActionCard(title: "Quick Transfers",
                       description: "Send money instantly to anyone in your contact list.",
                       buttonLabel: "Add people") {
                showContactList = true
                SecureLogger.debug("Quick transfer tapped", category: .general)
            }
            
            ActionCard(title: "Link Bank Account",
                       description: "To make inverstments, deposits, withdrawals and securely link your bank account.",
                       buttonLabel: "Connect bank",
                       isLoading: achVM.state == .loading) {
                Task { await achVM.startPlaidLink() }
                SecureLogger.debug("Link your bank tapped", category: .general)
            }
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
    
    // MARK: - Private Functions

    private func handleOnTask() async {
        await loadData()
        await userVM.fetchProfile()
    }

    private func loadData() async {
        await savingVM.loadAccounts()
    }
}
