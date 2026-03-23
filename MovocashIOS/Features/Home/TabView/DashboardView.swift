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
    @State private var showAccountList = false
    @State private var showPrimaryAccountDetails = false
    @State private var showAccountDetail = false
    @State private var showCreateView = false
    @State private var showEditNickname = false
    
    @State private var showViewCard = false
    @State private var showFunds = false
    
    private var displayAccount: SavingsAccountDetailsResponse? {
        savingVM.accountList?.accounts.first(where: { $0.isPrimary })
    }

    private var isViewCashAccount: Bool {
        guard let account = savingVM.accountList?.accounts.first(where: { !$0.isPrimary }) else {
            return false
        }
        return !account.isPrimary
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
                SavingAccountDetailView(accountId: account.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAccountList) {
            AccountListSheetView(savingsList: $savingVM.accountList, isPresented: $showAccountList)
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
                fromAccount: savingVM.accountList?.accounts.first(where: { $0.isPrimary }),
                nonPrimaryAccounts: savingVM.accountList?.accounts.filter({ !$0.isPrimary }) ?? []
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
        CustomHeaderView(userName: userVM.profile?.initials ?? "", userImage: userVM.profile?.profilePicture ?? "") {
            sessionManager.logoutWithConfirmation(appState: appState) {
                AppContainer.lockManager.logout()
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
                totalAvailableBalance: account.availableBalance,
                onCardTap: { showAccountDetail = true },
                onPrimaryTap: { showPrimaryAccountDetails = true },
                onCreateTap: { showCreateView = true },
                onViewCardTap: { showViewCard = true }
            )
            
            if isViewCashAccount {
                PrimaryButton(
                    title: "View Cash Accounts",
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
        await savingVM.loadAccounts()
    }
}
