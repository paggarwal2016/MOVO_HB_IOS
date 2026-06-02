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
    let container: AppContainer
    var onDeleted: (() -> Void)?

    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var cardVM: VCardViewModel

    init(
        cards: [VCardListResponse],
        primaryAccountId: Int?,
        primaryLinkedCard: VCardListResponse? = nil,
        container: AppContainer,
        onDeleted: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.primaryAccountId = primaryAccountId
        self.primaryLinkedCard = primaryLinkedCard
        self.container = container
        self.onDeleted = onDeleted
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _cardVM = StateObject(wrappedValue: container.makeVCardViewModel())
    }
    
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var selectedCard: VCardListResponse?
    @State private var showCardDetail = false
    @State private var showCreateCard = false
    @State private var deletedCardIds: Set<String> = []
    /// Holds the newly created card while the create sheet dismisses; the sheet's
    /// onDismiss then presents the confirmation for it.
    @State private var pendingCreatedCard: VCardListResponse? = nil
    /// The card whose confirmation screen is currently presented.
    @State private var createdCard: VCardListResponse? = nil

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
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showCreateCard, onDismiss: {
            // Once the create sheet has fully dismissed, present the confirmation
            // for the just-created card (if any).
            if let card = pendingCreatedCard {
                pendingCreatedCard = nil
                createdCard = card
            }
        }) {
            CreateCashCardView(
                vm: cardVM,
                onClose: { showCreateCard = false },
                onCreated: { card in
                    // Stash the card and dismiss the create sheet in the background.
                    pendingCreatedCard = card
                    showCreateCard = false
                }
            )
            .secured()
            .presentationDetents([.height(480)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        .fullScreenCover(item: $createdCard) { card in
            CashCardCreateSuccess(
                card: card,
                onDone: {
                    createdCard = nil
                    // Notify in the background so the list refreshes.
                    Task {
                        await cardVM.loadCards()
                        onDeleted?()
                    }
                }
            )
        }
        .navigationDestination(isPresented: $showCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: primaryAccountId,
                    primaryLinkedCard: primaryLinkedCard,
                    savingVM: savingVM,
                    container: container,
                    onDeleted: {
                        if let id = selectedCard?.id {
                            deletedCardIds.insert(id)
                        }
                        onDeleted?()
                    }
                )
            }
        }
        .globalAlert()
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
