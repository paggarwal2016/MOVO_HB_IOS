//
//  ViewCardsListScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 10/04/26.
//

import SwiftUI

struct ViewCardsListScreen: View {
    
    let cards: [VCardListResponse]
    let primaryAccountId: Int?
    let container: AppContainer
    var onDeleted: (() -> Void)?
    
    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var cardVM: VCardViewModel
    
    init(
        cards: [VCardListResponse],
        primaryAccountId: Int?,
        container: AppContainer,
        onDeleted: (() -> Void)? = nil
    ) {
        self.cards = cards
        self.primaryAccountId = primaryAccountId
        self.container = container
        self.onDeleted = onDeleted
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _cardVM = StateObject(wrappedValue: container.makeVCardViewModel())
    }
    
    @State private var selectedCard: VCardListResponse?
    @State private var showCardDetail = false
    @State private var showCreateCard = false
    @State private var deletedCardIds: Set<String> = []

    // Use VM cards after first load, filtered by optimistic deletes.
    private var displayCards: [VCardListResponse] {
        (cardVM.hasLoadedCards ? cardVM.cards : cards).filter { !deletedCardIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            Group {
                if displayCards.isEmpty {
                    emptyState
                } else {
                    cardsList
                }
            }
        }
        .navigationTitle("Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.movo.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateCard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.movo.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateCard) {
            CreateCashCardView(
                onCancel: { showCreateCard = false },
                onCreate: { nickname, pin in
                    await createCard(nickname: nickname, pin: pin)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card,
                    primaryAccountId: primaryAccountId,
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
    
    // MARK: - Create Card
    
    private func createCard(nickname: String, pin: String) async {
        do {
            _ = try await cardVM.createVCard(
                request: CreateVCardRequest(nickname: nickname, pin: pin, userAction: "VCARD-CREATION")
            )
            showCreateCard = false
            ToastManager.shared.show("Card \"\(nickname)\" created!", style: .success, position: .bottom)
            await cardVM.loadCards()
            onDeleted?()
        } catch {
            ToastManager.shared.show("Failed to create card. Please try again.", style: .error, position: .bottom)
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
