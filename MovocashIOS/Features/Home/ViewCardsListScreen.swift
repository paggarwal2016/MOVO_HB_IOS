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
    
    // Use VM cards after first load, otherwise show what DashboardView passed in.
    private var displayCards: [VCardListResponse] {
        cardVM.hasLoadedCards ? cardVM.cards : cards
    }
    
    var body: some View {
        Group {
            if displayCards.isEmpty {
                emptyState
            } else {
                cardsList
            }
        }
        .navigationTitle("Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateCard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
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
                        onDeleted?()
                        Task { await cardVM.loadCards() }
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
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)
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
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                Image(systemName: "creditcard.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.secTcolor)
            }
            Text("No Cards Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.preTcolor)
            Text("Cards you create will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.secTcolor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}
