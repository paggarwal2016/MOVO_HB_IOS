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
    @State private var showTransactions = false
    @State private var showCreateCashCard = false
    @State private var showEditNickname = false
    
    @State private var showViewCard = false
    @State private var showFunds = false

    @State private var showMoveMoney = false
    @State private var showFundAccount = false

    @State private var showContactList = false
    @State private var showInternalTransfer = false
    
    @State private var showViewCardList = false
    
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
            message: "Enter a new nickname for your savings account.",
            placeholder: "Type here...",
            config: TextInputAlertConfig(primaryLabel: "Save"),
            onCreate: { name in
                guard let accountId = displayAccount?.id else { return }
                Task { await savingVM.updateNickname(name: name, accountId: accountId) }
            }
        )
        .overlay {
            if savingVM.state == .loading && !showCreateCashCard {
                SpinnerView()
            }
        }
        .sheet(isPresented: $showAccountDetail) {
            if let account = displayAccount {
                SavingAccountDetailView(accountId: account.id, showAccountCard: true, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showTransactions) {
            if let account = displayAccount {
                SavingAccountDetailView(accountId: account.id, showAccountCard: false, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAccountList) {
            AccountListSheetView(savingsList: $savingVM.accountList, isPresented: $showAccountList, container: container)
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
        .sheet(isPresented: $showInternalTransfer) {
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
                },
                onInternalTransfer: {
                    showMoveMoney = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showInternalTransfer = true
                    }
                }
            )
        }
        .sheet(isPresented: $showViewCardList) {
            ViewCardsListScreen(isPresented: $showViewCardList, container: container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked, appState.isAuthenticated else { return }
            await handleOnTask()
        }
        .onAppear {
            showCreateCashCard = false
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
                onCardTap: { showPrimaryAccountDetails = true },
                onPrimaryTap: { showEditNickname = true },
                onViewCardTap: { showViewCard = true }
            )

            // ── Quick actions ──────────────────────────────────────────────
            HStack(spacing: 12) {
                quickActionButton(icon: "list.bullet.rectangle", title: "Transactions") {
                    showTransactions = true
                }
                quickActionButton(icon: "person.text.rectangle", title: "Move Money") {
                    showMoveMoney = true
                }
            }
            .padding(.horizontal, 15)

            cashCardPromoCard
//            
//            PrimaryButton(
//                title: "View Cards",
//                backgroundColor: .orange.opacity(0.1),
//                textColor: .black
//            ) {
//                showViewCardList = true
//            }
//            .padding()
//            .frame(height: 60)
                        
            ActionCard(title: "Pay Anyone",
                       description: "Send money instantly to anyone in your contact list.",
                       buttonLabel: "Send Money") {
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
    
    
    // MARK: - Cash Card Promo Card

    private var cashCardPromoCard: some View {
        VStack(spacing: 0) {

            // Top — image + title/description
            Button {
                showCreateCashCard = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color(.systemGray2))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Card")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Create a new virtual cash card for instant payments.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isViewCashAccount {
                Divider()
                    .padding(.horizontal, 16)

                // Bottom — view cash cards (full-width tap area)
                Button {
                    //showAccountList = true
                    showViewCardList = true
                } label: {
                    HStack {
                        Text("View Cash Cards")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .padding(.horizontal, 15)
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

    private func createCashCard(nickname: String, pin: String) async {
        do {
            let account = try await savingVM.createSavingAccount(
                request: SavingsAccountRequest.CreateAccount(nickname: nickname)
            )
            _ = try await vm.postVCard(
                request: VCardsRequest(pin: pin, accountId: account.id)
            )
            showCreateCashCard = false
            await savingVM.loadAccounts()
            ToastManager.shared.show("Cash card \"\(nickname)\" created!", style: .success, position: .bottom)
        } catch {
            ToastManager.shared.show("Failed to create cash card. Please try again.", style: .error, position: .bottom)
        }
    }

    @ViewBuilder
    private func quickActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
