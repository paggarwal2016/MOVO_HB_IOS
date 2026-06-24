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
    @StateObject private var payeeFlow: PayeeTransferModel
    @ObservedObject var dashboardVM: DashboardViewModel
    @ObservedObject private var primaryCardStore: PrimaryCardStore

    @Binding var selectedTab: Tab

    private let container: AppContainer
    /// Title passed from the tab's MENU label (API-driven). Not currently rendered
    /// — the Home header shows the logo — but available for display if needed.
    private let screenTitle: String
    
    init(container: AppContainer, dashboardVM: DashboardViewModel, vm: VCardViewModel, selectedTab: Binding<Tab>, screenTitle: String = "Home") {
        self.container = container
        self.dashboardVM = dashboardVM
        self.vm = vm
        self.screenTitle = screenTitle
        _selectedTab = selectedTab
        _primaryCardStore = ObservedObject(wrappedValue: container.primaryCardStore)
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _achVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
        _payeeFlow = StateObject(wrappedValue: PayeeTransferModel(container: container))
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
    @State private var showAllFrequents = false
    @State private var showInternalTransfer = false
    @State private var showViewCardList = false
    @State private var showQuickPayView = false
    @State private var showCreateContact = false
    /// True while the create-contact API call is in flight — shows the spinner.
    @State private var isCreatingContact = false
    // Set to true by any child screen that completes a successful action;
    // triggers a single dashboard refresh on return.
    @State private var needsDashboardRefresh = false
    /// Drives the contact picker sheet. Carries the API-driven title from the
    /// dashboard PAYANYONE section so it is captured at present time (avoids a
    /// state-vs-present race that would otherwise show the default title).
    @State private var selectedCard: VCardListResponse? = nil
    /// Dedicated navigation flag for CardDetailSheet — decoupled from selectedCard
    /// to avoid a SwiftUI NavigationStack corruption when the binding's `set`
    /// closure mutates state mid-animation (causing a permanent blank dashboard).
    @State private var showCardDetail = false
    @State private var isLinkingPlaid = false
    @State private var showPlaidInfo = false
    @State private var plaidInfoAllowFunding = true
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false
    @State private var showFirstCardReward = false
    @State private var didCheckFirstCardReward = false
    /// The card just created in CreateCashCardView. Held while the create sheet
    @State private var createdCashCard: VCardListResponse? = nil
    /// Drives the post-create success cover.
    @State private var showCashCardSuccess = false
    @State private var showInsufficientBalance = false
    /// true = branch A (no linked bank → open Plaid), false = branch B (has bank → open Fund screen)
    @State private var insufficientBalanceUsePlaid = false
    /// Drives the custom invite bottom sheet.
    @State private var showInvite = false
    /// Set when the invite SMS was sent, so the success alert shows after the
    /// invite sheet dismisses (a root alert can't present over a sheet).
    @State private var inviteSent = false
    
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
            if dashboardVM.isRefreshing || isCreatingContact {
                // Scrim — black-on-alpha is intentional; works on both light and dark backgrounds.
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                // Center the spinner — the ZStack is top-aligned, so without this the
                // indicator would pin to the top and cover the header.
                SpinnerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .dimmingOverlay(isActive: isSheetActive)
        .sheet(isPresented: $showCreateCashCard, onDismiss: {
            if createdCashCard != nil { showCashCardSuccess = true }
        }) {
            CreateCashCardView(
                vm: vm,
                onClose: { showCreateCashCard = false },
                onCreated: { card in
                    createdCashCard = card
                    showCreateCashCard = false
                    Task { await dashboardVM.refresh() }
                }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .fullScreenCover(isPresented: $showCashCardSuccess, onDismiss: {
            createdCashCard = nil
        }) {
            if let card = createdCashCard {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    CashCardCreateSuccess(card: card, onDone: {
                        selectedCard = createdCashCard
                        showCardDetail = true
                        var tx = SwiftUI.Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) { showCashCardSuccess = false }
                    })
                    .frame(width: 320)
                }
                .presentationBackground(.clear)
            }
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
                    preselectedFromCard: primaryCardStore.card,
                    primaryLinkedCard: primaryCardStore.card,
                    initialCards: dashboardVM.apiCards,
                    container: container,
                    onDismiss: { needsDashboardRefresh = true }
                )
            }
        }
                
        .fullScreenCover(isPresented: $showCreateContact, onDismiss: { payeeFlow.popupDidDismiss() }) {
            AddContactSheet(container: contactVM, payeeFlow: payeeFlow, isSubmitting: $isCreatingContact, countryCode: "+1", onSave: { data in
                // The sheet stays open while we create the contact and run check-intent.
                // On check-intent success the model raises the in-sheet enroll popup; on
                // any failure the sheet remains open (error toast shows).
                Task {
                    isCreatingContact = true
                    let created = await contactVM.createContact(
                        nickname: data.nickname,
                        phoneNumber: data.phoneE164
                    )
                    guard created else { isCreatingContact = false; return }
                    await payeeFlow.prepareConfirmation(for: ContactRecord(
                        id: data.phoneE164,
                        isFav: false,
                        nickname: data.nickname,
                        createdAt: Date(),
                        phoneNumber: data.phoneE164,
                        isAdded: true,
                        updatedAt: Date()
                    ))
                    isCreatingContact = false
                }
            }, onContinue: {
                // Continue tapped in the enroll popup — dismiss this sheet; the transfer
                // is presented from onDismiss via popupDidDismiss().
                contactVM.clear()
                showCreateContact = false
            })
        }

        .fullScreenCover(isPresented: $showQuickPayView) {
            QuickPayView(
                container: container,
                primaryLinkedCard: primaryCardStore.card,
                cards: dashboardVM.cards,
                title: "Quick Pay", // dashboardVM.quickPayTitle
                onSuccess: { needsDashboardRefresh = true }
            )
        }
        
        .fullScreenCover(isPresented: $showAllFrequents) {
            AllFrequentsView(
                contactVM: contactVM,
                container: container,
                cards: dashboardVM.cards,
                primaryLinkedCard: primaryCardStore.card,
                onSuccess: { needsDashboardRefresh = true }
            )
        }
        .payeeTransferFlow(
            payeeFlow,
            container: container,
            cards: dashboardVM.cards,
            primaryLinkedCard: primaryCardStore.card,
            onSuccess: { needsDashboardRefresh = true }
        )
        .fullScreenCover(isPresented: $showFundAccount) {
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
        .fullScreenCover(isPresented: $showInsufficientBalance) {
            InsufficientBalanceDialog(
                balance: dashboardVM.primaryAccount?.availableBalance ?? 0,
                onAddMoney: {
                    showInsufficientBalance = false
                    if insufficientBalanceUsePlaid {
                        plaidInfoAllowFunding = true
                        showPlaidInfo = true
                    } else {
                        showFundAccount = true
                    }
                },
                onDismiss: { showInsufficientBalance = false }
            )
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showInternalTransfer) {
            if let account = displayAccount {
                InternalTransferView(
                    toClientId: account.clientId,
                    fromAccount: account,
                    nonPrimaryAccounts: savingVM.accountList?.data.accounts.filter { !$0.isPrimary } ?? [],
                    preselectedFromCard: primaryCardStore.card,
                    primaryLinkedCard: primaryCardStore.card,
                    initialCards: dashboardVM.apiCards,
                    container: container,
                    onDismiss: { needsDashboardRefresh = true }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
            }
        }
        .sheet(isPresented: $showInvite, onDismiss: {
            // Show the success alert only after the sheet is fully gone — a root
            // alert can't present over a sheet. Then "Let's Move On" → Dashboard.
            guard inviteSent else { return }
            inviteSent = false
            AlertManager.shared.showCustom(
                title: "Invite Sent",
                message: "Invite sent successfully",
                primary: "Let's Move On",
                onPrimary: {
                    NotificationCenter.default.post(name: .returnToDashboard, object: nil)
                }
            )
        }) {
            ShareInviteSheet(
                container: container,
                onClose: { showInvite = false },
                onInviteSent: {
                    // Mark success, then dismiss the sheet; the alert fires in onDismiss.
                    inviteSent = true
                    showInvite = false
                }
            )
            .presentationDetents([.height(400)])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .sheet(isPresented: $showMoveMoney) {
            MoveMoneyMenuView(
                onFundAccount: {
                    showMoveMoney = false
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); showFundAccount = true }
                },
                onInternalTransfer: {
                    showMoveMoney = false
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); showInternalTransfer = true }
                }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .navigationDestination(isPresented: $showViewCardList) {
            ViewCardsListScreen(
                cards: dashboardVM.cards,
                primaryAccountId: dashboardVM.primaryAccount?.id,
                primaryLinkedCard: primaryCardStore.card,
                primaryAccount: dashboardVM.primaryAccount,
                container: container,
                onChanged: { needsDashboardRefresh = true }
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
        .onChange(of: showCardDetail) { isShowing in
            if !isShowing { selectedCard = nil }
        }
        .navigationDestination(isPresented: $showCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: dashboardVM.primaryAccount?.id,
                    primaryLinkedCard: primaryCardStore.card,
                    primaryAccount: dashboardVM.primaryAccount,
                    cards: dashboardVM.cards,
                    savingVM: savingVM,
                    container: container,
                    canDelete: card.id != primaryCardStore.card?.id,
                    onDeleted: { needsDashboardRefresh = true },
                    onChanged: { needsDashboardRefresh = true }
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
        .sheet(isPresented: $showPlaidInfo, onDismiss: {
            // Start Plaid only after the info sheet is fully gone.
            if continueToPlaid {
                continueToPlaid = false
                startPlaidFlow = true
            }
        }) {
            BankLinkedInfoScreen(onContinue: { continueToPlaid = true })
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Color.movo.cardSurface)
        }
        .plaidLinkFlow(
            isActive: $startPlaidFlow,
            plaidVM: achVM,
            container: container,
            primaryAccount: dashboardVM.primaryAccount,
            allowFunding: plaidInfoAllowFunding,
            onDone: { needsDashboardRefresh = true }
        )
        
        .onChange(of: needsDashboardRefresh) { shouldRefresh in
            guard shouldRefresh else { return }
            needsDashboardRefresh = false
            Task { await dashboardVM.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            // Collapse any dashboard-originated push (e.g. FundAccountView) back to
            // the dashboard in one transition, then refresh.
            showFundAccount = false
            showInternalTransfer = false
            showPlaidInfo = false
            showInvite = false
            needsDashboardRefresh = true
        }
        .onAppear {
            showCreateCashCard = false
            maybeShowFirstCardReward()
        }
        .onChange(of: dashboardVM.hasLoadedCards) { _ in
            maybeShowFirstCardReward()
        }
        .fullScreenCover(isPresented: $showFirstCardReward) {
            // Both actions simply return to the Dashboard — neither opens Card Details.
            FirstCardRewardView(
                onViewDetails: { setFirstCardReward(false) },
                onClose: { setFirstCardReward(false) }
            )
        }
    }

    /// Shows the one-time first-card reward for newly registered users.
    ///
    /// The `pendingFirstCardReward` flag is set on the post-registration landing
    /// (`HomeTabBarView`); this consumes it using the primary card already
    /// decoded from the Dashboard API (`primaryCardStore.card`) — no extra
    /// API call. If the card isn't ready yet at first appear, the flag stays set
    /// and the `.onChange` on `primaryLinkedCard` retries once it loads. The
    /// session guard prevents re-checking on tab re-entry.
    private func maybeShowFirstCardReward() {
        guard !didCheckFirstCardReward else { return }
        guard UserDefaults.standard.bool(forKey: "pendingFirstCardReward") else { return }
        // Wait until the MYCARDS payload has resolved so we can reliably tell whether
        // a secondary card exists before deciding (the `.onChange` retries on load).
        guard dashboardVM.hasLoadedCards else { return }

        // One-shot check — consume the flag whether or not we show the review.
        didCheckFirstCardReward = true
        UserDefaults.standard.set(false, forKey: "pendingFirstCardReward")

        // First-time flow applies only when a secondary card (a non-primary card in
        // the My Cards list) was issued alongside the primary. The reward simply
        // returns to the Dashboard when dismissed. No secondary card → skip silently.
        guard dashboardVM.cards.first != nil else { return }
        setFirstCardReward(true)
    }

    /// Show/hide the reward cover without its own bottom slide — `FirstCardRewardView`
    /// runs the center zoom itself, on both present and dismiss.
    private func setFirstCardReward(_ visible: Bool) {
        // Qualify SwiftUI.Transaction — the app also defines a `Transaction` model.
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { showFirstCardReward = visible }
    }

    // MARK: - Subviews
    
    private var headerView: some View {
        CustomHeaderView(
            userName: dashboardVM.userDetails?.firstName ?? "",
            userImage: dashboardVM.userDetails?.profilePicture ?? ""
        ) {
            selectedTab = .profile
        }
    }

    /// Standalone invite CTA — accent-outlined pill (QuickActionButton `.custom`)
    /// that opens the custom invite bottom sheet (ShareInviteSheet).
    private var inviteButton: some View {
        QuickActionButton(
            title: "Invite someone to Movo",
            icon: "person.badge.plus",
            appearance: .init(fill: .clear, border: Color.movo.accent, text: Color.movo.accent),
            uppercased: true
        ) {
            showInvite = true
        }
        .padding(.horizontal, 15)
    }
    
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                headerView
                savingsSection
                if dashboardVM.dashboard?.data != nil {
                    inviteButton
                }
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
                        hasVCards: primaryCardStore.card != nil,
                        onCardTap: { showPrimaryAccountDetails = true },
                        onViewCardTap: {
                            selectedCard = primaryCardStore.card
                            showCardDetail = true
                        },
                        onQuickAction: handleQuickAction
                    )
                }
            case .payAnyone(let data):
                // Capture the API-driven title for the whole section (both branches),
                // so the contact-picker sheet reads the correct title at present time.
                Group {
                    if data.favContactList.isEmpty {
                        ActionCard(
                            title: data.title ?? "",
                            description: data.description ?? "Tap to send. They get it the moment you do.",
                            buttonLabel: data.actions.first?.label ?? "Add payee"
                        ) {
                            showQuickPayView = true
                        }
                    } else {
                        PayAnyoneAddContactView(
                            title: data.title ?? "",
                            contacts: data.favContactList,
                            onAddTap: {
                                showQuickPayView = true
                            },
                            onContactTap: { record in
                                payeeFlow.tap(ContactRecord(
                                    id: record.id,
                                    isFav: false,
                                    nickname: record.nickname,
                                    createdAt: Date(),
                                    phoneNumber: record.phoneNumber,
                                    isAdded: false,
                                    updatedAt: Date()
                                ))
                            },
                            onSeeAllTap: { showAllFrequents = true }
                        )
                    }
                }
                .onAppear { dashboardVM.quickPayTitle = data.title ?? "Pay Anyone" }
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
        if !dashboardVM.hasLoadedCards {
            CardSkeletonView()
                .frame(maxWidth: .infinity)
        } else if dashboardVM.cards.isEmpty {
            CreateCardView(
                title: data.title,
                message: data.description,
                onTap: { showCreateCashCard = true }
            )
            .frame(maxWidth: .infinity)
        } else {
            CardSelectorView(
                cards: dashboardVM.cards,
                sectionTitle: data.title,
                onTap: { handleCreateCardTap() },
                onEyeTap: { card in
                    selectedCard = card
                    showCardDetail = true
                },
                onShowMore: { showViewCardList = true }
            )
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Actions
    
    /// Handles the "+" (create card) tap in the My Cards section.
    /// When the primary account has a zero available balance, card creation is
    /// gated behind a prompt to fund the account first.
    /// Minimum available balance required to create a new virtual card.
    private static let minCardCreationBalance: Decimal = 5

    private func handleCreateCardTap() {
        let account = dashboardVM.primaryAccount
        let availableBalance = account?.availableBalance ?? 0
        let accountBalance   = account?.accountBalance ?? 0
        let hasLinkedAccount = !(dashboardVM.linkedAccounts?.linkedAccounts ?? []).isEmpty

        // Sufficient balance → proceed straight to card creation.
        guard availableBalance < Self.minCardCreationBalance else {
            showCreateCashCard = true
            return
        }
        
        // Show the new centered dialog. Branch A (no linked bank) opens Plaid;
        // Branch B (has linked bank or account balance) opens the Fund screen.
        insufficientBalanceUsePlaid = !hasLinkedAccount && accountBalance == 0
        showInsufficientBalance = true
    }
    
    private func handleQuickAction(_ action: String) {
        switch action {
        case "ACTIVITY":              showTransactions = true
        case "MOVE-MONEY":            showMoveMoney = true
        case "FUND-ACCOUNT":
            if (dashboardVM.linkedAccounts?.linkedAccounts ?? []).isEmpty {
                // No linked bank → show the Plaid info sheet to link one first.
                plaidInfoAllowFunding = true
                showPlaidInfo = true
            } else {
                // Has at least one linked bank → go straight to the Fund Account screen.
                showFundAccount = true
            }
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
                QuickActionButton(
                    title: moneyAction.label,
                    icon: moneyAction.action == "FUND-ACCOUNT" ? "arrow.down.to.line" : "arrow.left.arrow.right",
                    appearance: .accent
                ) {
                    onQuickAction(moneyAction.action)
                }
            }

            if let txAction = accountData.actions.first(where: { $0.action == "ACTIVITY" }) {
                QuickActionButton(title: txAction.label, icon: "clock", appearance: .secondary) {
                    onQuickAction(txAction.action)
                }
            }
        }
    }
}
