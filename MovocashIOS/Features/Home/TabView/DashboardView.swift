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

    @ObservedObject var vm: VCardViewModel
    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var achVM: PlaidAchViewModel
    @StateObject private var contactVM: ContactViewModel
    @ObservedObject var dashboardVM: DashboardViewModel

    private let container: AppContainer

    init(container: AppContainer, dashboardVM: DashboardViewModel, vm: VCardViewModel) {
        self.container = container
        self.dashboardVM = dashboardVM
        self.vm = vm
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
    }

    // MARK: - Navigation State

    @State private var showPrimaryAccountDetails = false
    @State private var showAccountDetail = false
    @State private var showTransactions = false
    @State private var showCreateCashCard = false
    @State private var showViewCard = false
    @State private var showFunds = false
    @State private var showMoveMoney = false
    @State private var showFundAccount = false
    @State private var showContactList = false
    @State private var showAllFrequents = false
    @State private var showInternalTransfer = false
    @State private var showViewCardList = false
    // Set to true by any child screen that completes a successful action;
    // triggers a single dashboard refresh on return.
    @State private var needsDashboardRefresh = false
    @State private var quickTransferContact: ContactRecord? = nil
    @State private var selectedCard: VCardListResponse? = nil
    @State private var isLinkingPlaid = false
    @State private var showPlaidInfo = false
    @State private var plaidInfoAllowFunding = true

    private var displayAccount: SavingsAccountInfo? {
        dashboardVM.primaryAccount
    }

    // MARK: - Body

    private var isSheetActive: Bool {
        showCreateCashCard || showMoveMoney || showPrimaryAccountDetails || showPlaidInfo
    }

    var body: some View {
        ZStack(alignment: .top) {
            MovoBackground()
            VStack(spacing: 0) {
                scrollContent
            }
           StatusBarScrim()
            if dashboardVM.isRefreshing {
                // Scrim — black-on-alpha is intentional; works on both light and dark backgrounds.
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                SpinnerView()
            }
        }
        .dimmingOverlay(isActive: isSheetActive)
        .sheet(isPresented: $showCreateCashCard) {
            CreateCashCardView(
                onCancel: { showCreateCashCard = false },
                onCreate: { nickname, pin in
                    await createCashCard(nickname: nickname, pin: pin)
                }
            )
            .presentationDetents([.height(480)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .sheet(isPresented: $showAccountDetail) {
            if let account = displayAccount {
                SavingAccountDetailView(accountId: account.id, showAccountCard: true, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showViewCard) {
            if let account = displayAccount {
                ViewCardScreen(isPresented: $showViewCard, accountId: account.id, container: container)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showFunds) {
            if let account = displayAccount {
                InternalTransferView(
                    toClientId: account.clientId,
                    fromAccount: account,
                    nonPrimaryAccounts: savingVM.accountList?.data.accounts.filter { !$0.isPrimary } ?? [],
                    preselectedFromCard: vm.primaryLinkedCard,
                    primaryLinkedCard: vm.primaryLinkedCard,
                    initialCards: vm.apiCards,
                    container: container,
                    onDismiss: { needsDashboardRefresh = true }
                )
            }
        }
        .sheet(isPresented: $showContactList) {
            PayAnyoneContactPickerView(
                container: container,
                cards: vm.cards,
                primaryLinkedCard: dashboardVM.primaryLinkedCard,
                onSuccess: { needsDashboardRefresh = true }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllFrequents) {
            AllFrequentsView(
                contactVM: contactVM,
                container: container,
                cards: vm.cards,
                primaryLinkedCard: dashboardVM.primaryLinkedCard,
                onSuccess: { needsDashboardRefresh = true }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $quickTransferContact) { contact in
            QuickTransferView(
                contact: contact,
                container: container,
                cards: vm.cards,
                primaryLinkedCard: dashboardVM.primaryLinkedCard,
                onSuccess: { needsDashboardRefresh = true }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showFundAccount) {
            if let account = displayAccount {
                FundAccountView(
                    container: container,
                    initialAccounts: dashboardVM.linkedAccounts?.linkedAccounts ?? [],
                    primaryAccount: account,
                    onSuccess: { needsDashboardRefresh = true },
                    onAccountLinked: { needsDashboardRefresh = true }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
            }
        }
        .fullScreenCover(isPresented: $showInternalTransfer) {
            if let account = displayAccount {
                InternalTransferView(
                    toClientId: account.clientId,
                    fromAccount: account,
                    nonPrimaryAccounts: savingVM.accountList?.data.accounts.filter { !$0.isPrimary } ?? [],
                    preselectedFromCard: vm.primaryLinkedCard,
                    primaryLinkedCard: vm.primaryLinkedCard,
                    initialCards: vm.apiCards,
                    container: container,
                    onDismiss: { needsDashboardRefresh = true }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
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
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .navigationDestination(isPresented: $showViewCardList) {
            ViewCardsListScreen(
                cards: vm.cards,
                primaryAccountId: dashboardVM.primaryAccount?.id,
                primaryLinkedCard: dashboardVM.primaryLinkedCard,
                container: container,
                onDeleted: {}
            )
        }
        .navigationDestination(isPresented: $showTransactions) {
            if let account = displayAccount {
                    TransactionListView(container: container,
                                        accountId: account.id,
                                        mode: .common)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedCard != nil },
            set: { if !$0 { selectedCard = nil } }
        )) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: dashboardVM.primaryAccount?.id,
                    primaryLinkedCard: dashboardVM.primaryLinkedCard,
                    savingVM: savingVM,
                    container: container,
                    canDelete: card.id != vm.primaryLinkedCard?.id,
                    onDeleted: {}
                )
            }
        }
        .sheet(isPresented: $showPrimaryAccountDetails) {
            if let account = displayAccount {
                AccountDetailsView(account: account, onNicknameUpdated: { name in
                    Task {
                        await savingVM.updateNickname(name: name, accountId: account.id)
                        dashboardVM.optimisticallyUpdateNickname(name)
                        await dashboardVM.refresh()
                    }
                })
                .presentationDetents([.height(385)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Color.movo.cardSurface)
            }
        }
        .sheet(isPresented: $showPlaidInfo) {
            BankLinkedInfoScreen(
                container: container,
                plaidVM: achVM,
                primaryAccount: dashboardVM.primaryAccount,
                allowFunding: plaidInfoAllowFunding,
                onSuccess: { needsDashboardRefresh = true }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        
        .onChange(of: needsDashboardRefresh) { shouldRefresh in
            guard shouldRefresh else { return }
            needsDashboardRefresh = false
            Task { await dashboardVM.refresh() }
        }
        .onChange(of: vm.primaryLinkedCard?.id) { _ in
            dashboardVM.primaryLinkedCard = vm.primaryLinkedCard
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            // Reset every navigation flag so the inner NavigationStack has no active
            // destinations to animate away when the flow changes to .choice.
            // This fires in the same notification cycle as MovocashIOSApp.onReceive
            // (which is deferred by one Task), so these dismissals happen first.
            selectedCard = nil
            showTransactions = false
            showViewCardList = false
            showViewCard = false
            showMoveMoney = false
            showContactList = false
            showAllFrequents = false
            showFundAccount = false
            showInternalTransfer = false
            showAccountDetail = false
            showCreateCashCard = false
            quickTransferContact = nil
        }
        .onAppear {
            showCreateCashCard = false
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        CustomHeaderView(
            userName: dashboardVM.userDetails?.firstName ?? "",
            userImage: dashboardVM.userDetails?.profilePicture ?? ""
        ) {
//            sessionManager.logoutWithConfirmation(appState: appState) {
//                lockManager.logout()
//            }
        }
    }

private var scrollContent: some View {
    ScrollView(showsIndicators: false) {
        LazyVStack(spacing: 20) {
            headerView
            savingsSection
        }
        .padding(.top, 56)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
    }
    .ignoresSafeArea(edges: .top)
    .refreshable {
        await Task {
            await dashboardVM.refresh()
            await vm.loadCards(primaryAccountId: dashboardVM.primaryAccount?.id)
        }.value
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

    // MARK: - Section Views

    @ViewBuilder
    private func dashboardSectionView(_ section: DashboardSection) -> some View {
        Group {
            switch section {
        case .primaryAccount(let accountData):
            if let account = displayAccount {
                PrimaryAccountContent(
                    account: account,
                    accountData: accountData,
                    hasVCards: vm.primaryLinkedCard != nil,
                    onCardTap: { showPrimaryAccountDetails = true },
                    onViewCardTap: {
                        selectedCard = vm.primaryLinkedCard
                    },
                    onQuickAction: handleQuickAction
                )
            }
        case .payAnyone(let data):
            if data.favContactList.isEmpty {
                ActionCard(
                    title: data.title ?? "Pay anyone, instantly",
                    description: data.description ?? "Tap to send. They get it the moment you do.",
                    buttonLabel: data.actions.first?.label ?? "Add payee"
                ) {
                    showContactList = true
                    SecureLogger.debug("Quick transfer tapped", category: .general)
                }
            } else {
                PayAnyoneAddContactView(
                    title: data.title ?? "Pay Anyone",
                    contacts: data.favContactList,
                    onAddTap: { showContactList = true },
                    onContactTap: { record in
                        quickTransferContact = ContactRecord(
                            id: record.id,
                            isFav: false,
                            nickname: record.nickname,
                            createdAt: Date(),
                            phoneNumber: record.phoneNumber,
                            isAdded: false,
                            updatedAt: Date()
                        )
                    },
                    onSeeAllTap: { showAllFrequents = true }
                )
            }
        case .linkedAccounts(let data):
            LinkedAccountsSectionView(
                title: data.title,
                description: data.description,
                buttonLabel: data.actions.first?.label ?? "Link an account",
                accounts: data.linkedAccounts ?? [],
                isLoading: isLinkingPlaid || achVM.state == .loading,
                onLinkAccount: {
                    plaidInfoAllowFunding = false
                    showPlaidInfo = true
                    SecureLogger.debug("Link your bank tapped", category: .general)
                },
                onConnectAnother: {
                    plaidInfoAllowFunding = false
                    showPlaidInfo = true
                    SecureLogger.debug("Connect another bank tapped", category: .general)
                }
            )
        case .myCards(let data):
            myCardsSectionView(data)
        case .userDetails, .rewards, .menu, .unknown:
            EmptyView()
        }
        }
        .padding(.horizontal, 15)
    }

    @ViewBuilder
    private func myCardsSectionView(_ data: DashboardMyCards) -> some View {
        if !vm.hasLoadedCards {
            CardSkeletonView()
                .frame(maxWidth: .infinity)
        } else if vm.cards.isEmpty {
            CreateCardView(
                title: data.title,
                message: data.description,
                onTap: { showCreateCashCard = true }
            )
            .frame(maxWidth: .infinity)
        } else {
            CardSelectorView(
                cards: vm.cards,
                sectionTitle: data.title,
                onTap: { showCreateCashCard = true },
                onEyeTap: { card in
                    selectedCard = card
                },
                onShowMore: { showViewCardList = true }
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func createCashCard(nickname: String, pin: String) async {
        do {
            _ = try await vm.createVCard(request: CreateVCardRequest(nickname: nickname, pin: pin, userAction: "VCARD-CREATION"))
            showCreateCashCard = false
            ToastManager.shared.show("Cash card \"\(nickname)\" created!", style: .success, position: .bottom)
            await vm.loadCards(primaryAccountId: dashboardVM.primaryAccount?.id)
            await dashboardVM.refresh()
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }

    private func handleQuickAction(_ action: String) {
        switch action {
        case "ACTIVITY":          showTransactions = true
        case "MOVE-MONEY":            showMoveMoney = true
        case "FUND-ACCOUNT":          plaidInfoAllowFunding = true; showPlaidInfo = true
        default:                      break
        }
    }
}


// MARK: - Extracted Subview (Prevents re-renders during scroll)

struct PrimaryAccountContent: View {
    let account: SavingsAccountInfo
    let accountData: DashboardAccount
    let hasVCards: Bool
    let onCardTap: () -> Void
    let onViewCardTap: () -> Void
    let onQuickAction: (String) -> Void

    var body: some View {
        BalanceCardView(
            account: account,
            showViewCard: hasVCards, // showViewCard: accountData.isPVCardActivated == "Active" && hasVCards,
            onCardTap: onCardTap,
            onViewCardTap: onViewCardTap
        )

        HStack(spacing: 10) {
            if let moneyAction = accountData.actions.first(where: {
                $0.action == "MOVE-MONEY" || $0.action == "FUND-ACCOUNT"
            }) {
                QuickActionButton(action: moneyAction, style: .accent) {
                    onQuickAction(moneyAction.action)
                }
            }

            if let txAction = accountData.actions.first(where: { $0.action == "ACTIVITY" }) {
                QuickActionButton(action: txAction, style: .secondary) {
                    onQuickAction(txAction.action)
                }
            }
        }
    }
}


// MARK: - Quick Action Pill Button

private struct QuickActionButton: View {
    enum Style { case accent, secondary }

    let action: DashboardAction
    let style: Style
    let onTap: () -> Void

    private var icon: String {
        switch action.action {
        case "FUND-ACCOUNT":  return "arrow.down.to.line"
        case "MOVE-MONEY":    return "arrow.left.arrow.right"
        case "ACTIVITY":      return "clock"
        default:              return "circle"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(action.label.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.4)
            }
            .foregroundColor(style == .accent ? Color.movo.background : Color.movo.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(pillBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pillBackground: some View {
        switch style {
        case .accent:
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.movo.accent)
        case .secondary:
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.movo.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        }
    }
}
