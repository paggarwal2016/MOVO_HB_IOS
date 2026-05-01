//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import SwiftUI

struct DashboardView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var sessionManager: SessionManager

    // MARK: - ViewModels

    @StateObject private var vm: VCardViewModel
    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var achVM: PlaidAchViewModel
    @ObservedObject var linkAccountVM: ACHViewModel
    @ObservedObject var dashboardVM: DashboardViewModel

    private let container: AppContainer

    init(container: AppContainer, dashboardVM: DashboardViewModel, linkAccountVM: ACHViewModel) {
        self.container = container
        self.dashboardVM = dashboardVM
        self.linkAccountVM = linkAccountVM
        _vm = StateObject(wrappedValue: container.makeVCardViewModel())
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }

    // MARK: - Navigation State

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
    @State private var showAccountList = false
    @State private var hasLoadedData = false
    @State private var selectedCard: VCardListResponse? = nil
    @State private var showCardDetail = false

    private var displayAccount: SavingsAccountInfo? {
        dashboardVM.primaryAccount
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
        .overlay { combinedOverlay }
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
                Task {
                    await savingVM.updateNickname(name: name, accountId: accountId)
                    dashboardVM.optimisticallyUpdateNickname(name)
                    await dashboardVM.refresh()
                }
            }
        )
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
                    nonPrimaryAccounts: savingVM.accountList?.data.accounts.filter { !$0.isPrimary } ?? [],
                    container: container,
                    onDismiss: { Task { await dashboardVM.refresh() } }
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
                    nonPrimaryAccounts: savingVM.accountList?.data.accounts.filter { !$0.isPrimary } ?? [],
                    container: container,
                    onDismiss: { Task { await dashboardVM.refresh() } }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showMoveMoney) {
            MoveMoneyMenuView(
                onFundAccount: {
                    showMoveMoney = false
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); showFundAccount = true }
                },
                onTransferMoney: {
                    showMoveMoney = false
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); showContactList = true }
                },
                onInternalTransfer: {
                    showMoveMoney = false
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); showInternalTransfer = true }
                }
            )
        }
        .navigationDestination(isPresented: $showViewCardList) {
            ViewCardsListScreen(
                cards: vm.cards,
                primaryAccountId: dashboardVM.primaryAccount?.id,
                container: container,
                onDeleted: { Task { await vm.loadCards() } }
            )
        }
        .navigationDestination(isPresented: $showCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: dashboardVM.primaryAccount?.id,
                    savingVM: savingVM,
                    container: container,
                    onDeleted: { Task { await vm.loadCards() } }
                )
            }
        }
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked, appState.isAuthenticated else { return }
            guard !hasLoadedData else { return }
            hasLoadedData = true
            async let cards: () = vm.loadCards()
            async let linkedAccounts: () = linkAccountVM.fetchAccounts()
            _ = await (cards, linkedAccounts)
        }
        .onAppear {
            showCreateCashCard = false
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        CustomHeaderView(
            userName: dashboardVM.userDetails?.initials ?? "",
            userImage: dashboardVM.userDetails?.profilePicture ?? ""
        ) {
            sessionManager.logoutWithConfirmation(appState: appState) {
                lockManager.logout()
            }
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                savingsSection
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await dashboardVM.refresh()
        }
    }

    @ViewBuilder
    private var savingsSection: some View {
        if let sections = dashboardVM.dashboard?.data {
            ForEach(sections.indices, id: \.self) { index in
                dashboardSectionView(sections[index])
            }
        } else if dashboardVM.state == .loading && dashboardVM.primaryAccount == nil {
            DashboardSkeletonView()
        }
    }

    @ViewBuilder
    private var combinedOverlay: some View {
        if dashboardVM.state == .loading && !showCreateCashCard && dashboardVM.primaryAccount == nil {
            SpinnerView()
        }
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

    // MARK: - Section Views

    @ViewBuilder
    private func dashboardSectionView(_ section: DashboardSection) -> some View {
        switch section {
        case .primaryAccount(let accountData):
            if let account = displayAccount {
                PrimaryAccountContent(
                    account: account,
                    accountData: accountData,
                    onCardTap: { showPrimaryAccountDetails = true },
                    onPrimaryTap: { showEditNickname = true },
                    onViewCardTap: { showViewCard = true },
                    onQuickAction: handleQuickAction
                )
            }
        case .payAnyone(let data):
            ActionCard(
                title: data.title,
                description: data.description,
                buttonLabel: data.actions.first?.label ?? "Send Money"
            ) {
                showContactList = true
                SecureLogger.debug("Quick transfer tapped", category: .general)
            }
        case .linkedAccounts(let data):
            LinkedAccountsSectionView(
                title: data.title,
                description: data.description,
                buttonLabel: data.actions.first?.label ?? "Link an account",
                accounts: linkAccountVM.accounts,
                isLoading: achVM.state == .loading,
                isLoadingAccounts: linkAccountVM.state == .loading,
                onLinkAccount: {
                    Task {
                        await achVM.startPlaidLink()
                        if achVM.linkedAccount != nil { await linkAccountVM.fetchAccounts() }
                    }
                    SecureLogger.debug("Link your bank tapped", category: .general)
                },
                onConnectAnother: {
                    Task {
                        await achVM.startPlaidLink()
                        if achVM.linkedAccount != nil { await linkAccountVM.fetchAccounts() }
                    }
                    SecureLogger.debug("Connect another bank tapped", category: .general)
                }
            )
        case .myCards(let data):
            myCardsSectionView(data)
        case .userDetails, .rewards, .menu, .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    private func myCardsSectionView(_ data: DashboardMyCards) -> some View {
        Group {
            if !vm.hasLoadedCards {
                CardSkeletonView()
                    .frame(height: 220)
            } else if vm.cards.isEmpty {
                CreateCardView(
                    title: data.title,
                    message: data.description,
                    onTap: { showCreateCashCard = true }
                )
            } else {
                CardSelectorView(
                    cards: vm.cards,
                    sectionTitle: data.title,
                    onTap: { showCreateCashCard = true },
                    onEyeTap: { card in
                        selectedCard = card
                        showCardDetail = true
                    },
                    onShowMore: { showViewCardList = true }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 15)
    }

    // MARK: - Actions

    private func createCashCard(nickname: String, pin: String) async {
        do {
            _ = try await vm.createVCard(request: CreateVCardRequest(nickname: nickname, pin: pin, userAction: "VCARD-CREATION"))
            showCreateCashCard = false
            ToastManager.shared.show("Cash card \"\(nickname)\" created!", style: .success, position: .bottom)
            await vm.loadCards()
        } catch {
            ToastManager.shared.show("Failed to create cash card. Please try again.", style: .error, position: .bottom)
        }
    }

    private func handleQuickAction(_ action: String) {
        switch action {
        case "TRANSACTIONS":          showTransactions = true
        case "MOVE-MONEY":            showMoveMoney = true
        case "ISSUE-A-PHYSICAL-CARD": break
        default:                      break
        }
    }
}

// MARK: - Extracted Subview (Prevents re-renders during scroll)
struct PrimaryAccountContent: View {
    let account: SavingsAccountInfo
    let accountData: DashboardAccount
    let onCardTap: () -> Void
    let onPrimaryTap: () -> Void
    let onViewCardTap: () -> Void
    let onQuickAction: (String) -> Void

    var body: some View {
        BalanceCardView(
            account: account,
            viewCardsLabel: accountData.actions.first(where: { $0.action == "VIEW-CARDS" })?.label,
            onCardTap: onCardTap,
            onPrimaryTap: onPrimaryTap,
            onViewCardTap: onViewCardTap
        )
        HStack(spacing: 10) {
            PrimaryButton(
                image: Image(systemName: "list.bullet.rectangle"),
                title: "Transactions",
                alignment: .center,
                backgroundColor: .white,
                textColor: .black
            ) {
                onQuickAction("TRANSACTIONS")
            }
            PrimaryButton(
                image: Image(systemName: "person.text.rectangle"),
                title: "Move Money",
                alignment: .center,
                backgroundColor: .white,
                textColor: .black
            ) {
                onQuickAction("MOVE-MONEY")
            }
        }
        .padding(.horizontal, 12)
    }
}
