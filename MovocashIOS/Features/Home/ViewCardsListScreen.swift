//
//  ViewCardsListScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/04/26.
//

import SwiftUI

struct ViewCardsListScreen: View {
    
    let cards: [VCardListResponse]
    let primaryAccountId: Int?
    let primaryLinkedCard: VCardListResponse?
    /// Primary account from the Dashboard — supplies the user-level `clientId`
    /// the card detail transfer needs.
    let primaryAccount: SavingsAccountInfo?
    let container: AppContainer
    /// Invoked when the user navigates back after creating or deleting a card,
    /// so the presenter (dashboard) can refresh to reflect the latest data.
    var onChanged: (() -> Void)?

    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var cardVM: VCardViewModel

    init(
        cards: [VCardListResponse],
        primaryAccountId: Int?,
        primaryLinkedCard: VCardListResponse? = nil,
        primaryAccount: SavingsAccountInfo? = nil,
        container: AppContainer,
        onChanged: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.primaryAccountId = primaryAccountId
        self.primaryLinkedCard = primaryLinkedCard
        self.primaryAccount = primaryAccount
        self.container = container
        self.onChanged = onChanged
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _cardVM = StateObject(wrappedValue: container.makeVCardViewModel())
    }

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var selectedCard: VCardListResponse?
    @State private var showCardDetail = false
    @State private var showCreateCard = false
    /// The card just created. Held while the create sheet dismisses so the
    /// success cover can present it next.
    @State private var createdCard: VCardListResponse? = nil
    /// Drives the post-create success cover.
    @State private var showCreateSuccess = false
    @State private var deletedCardIds: Set<String> = []
    /// Set when a card is created or deleted here; triggers a dashboard refresh on exit.
    @State private var hasChanges = false

    // Use VM cards after first load, filtered by optimistic deletes.
    private var displayCards: [VCardListResponse] {
        (cardVM.hasLoadedCards ? cardVM.cards : cards).filter { !deletedCardIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            VStack(spacing: 0) {
                navBar
                if displayCards.isEmpty {
                    emptyState
                } else {
                    cardsList
                }
            }
            StatusBarScrim()
            if cardVM.state == .loading {
                // Scrim — black-on-alpha is intentional; works on both light and dark backgrounds.
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                SpinnerView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showCreateCard, onDismiss: {
            // Present the success cover only after the create screen is fully gone.
            if createdCard != nil { showCreateSuccess = true }
        }) {
            CreateCashCardView(
                vm: cardVM,
                primaryAccountId: primaryAccountId ?? 0,
                onClose: { showCreateCard = false },
                onCreated: { card in
                    // Card created — hold it and dismiss the create sheet; the
                    // success cover presents next via the sheet's onDismiss.
                    createdCard = card
                    showCreateCard = false
                    hasChanges = true
                    // Reload this list in the background so the new card appears.
                    Task { await cardVM.loadCards(primaryAccountId: primaryAccountId) }
                }
            )
            .secured()
        }
        .fullScreenCover(isPresented: $showCreateSuccess, onDismiss: {
            createdCard = nil
        }) {
            if let card = createdCard {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    CashCardCreateSuccess(card: card, onDone: {
                        selectedCard = card
                        showCardDetail = true
                        var tx = SwiftUI.Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) { showCreateSuccess = false }
                    })
                    .frame(width: 320)
                }
                .presentationBackground(.clear)
            }
        }
        .navigationDestination(isPresented: $showCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: primaryAccountId,
                    primaryLinkedCard: primaryLinkedCard,
                    primaryAccount: primaryAccount,
                    cards: displayCards,
                    savingVM: savingVM,
                    container: container,
                    onDeleted: {
                        if let id = selectedCard?.id {
                            deletedCardIds.insert(id)
                        }
                        hasChanges = true
                        Task { await cardVM.loadCards(primaryAccountId: primaryAccountId) }
                    },
                    onChanged: { hasChanges = true }
                )
            }
        }
        .globalAlert()
        .onDisappear {
            // Refresh the dashboard on the way back only if something changed here.
            if hasChanges { onChanged?() }
        }
    }
    
    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Cards")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Button { showCreateCard = true } label: {
                CircleIconAvatar(systemName: "plus", size: 32, tint: .neutral)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Cards List

    private var cardsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(displayCards, id: \.id) { card in
                    Button {
                        selectedCard = card
                        showCardDetail = true
                    } label: {
                        CardItemView(card: card, isSelected: selectedCard?.id == card.id)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.movo.elevated)
                    .frame(width: 80, height: 80)
                Image(systemName: "creditcard.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.movo.textTertiary)
            }
            Text("No Cards Yet")
                .textStyle(Typography.cardHero)
                .foregroundStyle(Color.movo.textPrimary)
            Text("Cards you create will appear here.")
                .textStyle(Typography.body)
                .foregroundStyle(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}
