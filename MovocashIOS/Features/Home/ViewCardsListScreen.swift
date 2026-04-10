//
//  ViewCardsListScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 10/04/26.
//

import SwiftUI

struct ViewCardsListScreen: View {
    
    @Binding var isPresented: Bool
    @StateObject private var vm: VCardViewModel
    
    init(isPresented: Binding<Bool>, container: AppContainer) {
        _isPresented = isPresented
        _vm = StateObject(wrappedValue: container.makeVCardViewModel())
    }
    
    @State private var vcards: [VCardListResponse] = []
    @State private var selectedCard: VCardListResponse?
    
    // Derived binding — popup dismisses by setting selectedCard to nil
    private var isShowingDetail: Binding<Bool> {
        Binding(
            get: { selectedCard != nil },
            set: { if !$0 { selectedCard = nil } }
        )
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                vcardList
                    .navigationTitle("Cash Cards")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isPresented = false }
                                .foregroundStyle(Color.primary)
                                .fontWeight(.semibold)
                        }
                    }
            }
            
            if vm.state == .loading && !vcards.isEmpty {
                SpinnerView()
            }
        }
        .overlay { overlayContent }
        .globalAlert()
        .task { await getVCardsList }
    }
    
    // MARK: - Overlay
    
    @ViewBuilder
    private var overlayContent: some View {
        if let card = selectedCard {
            dimmedOverlay { selectedCard = nil } content: {
                VirtualCardDetailPopupView(
                    card: card.asVCardsResponse(),
                    isPresented: isShowingDetail
                )
                .padding(.horizontal, 15)
            }
        }
    }
    
    // MARK: - VCard List
    
    private var vcardList: some View {
        List {
            if vm.state == .loading && vcards.isEmpty {
                ForEach(0..<4, id: \.self) { _ in
                    AccountRowSkeleton().cardListRowStyle()
                }
            } else {
                ForEach(vcards.indices, id: \.self) { index in
                    VCardRowView(card: vcards[index])
                        .contentShape(Rectangle())
                        .onTapGesture { selectedCard = vcards[index] }
                        .cardListRowStyle()
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Load
    
    private var getVCardsList: Void {
        get async {
            do {
                vcards = try await vm.getVCardsList()
            } catch {
                ToastManager.shared.show("Failed to load cards.", style: .error, position: .bottom)
            }
        }
    }
}

// MARK: - List Row Style

private extension View {
    func cardListRowStyle() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.systemGroupedBackground))
            .listRowInsets(EdgeInsets())
    }
}

// MARK: - VCardListResponse → VCardsResponse

private extension VCardListResponse {
    func asVCardsResponse() -> VCardsResponse {
        VCardsResponse(
            cardNumber: cardNumber ?? "—",
            expiration: expiration ?? "—",
            lastFour: lastFour ?? "—",
            name: name ?? "—",
            cvc2: cvc2 ?? "—",
            firstName: firstName ?? "—",
            lastName: lastName ?? "—"
        )
    }
}

// MARK: - VCard Row

struct VCardRowView: View {
    
    let card: VCardListResponse
    
    var body: some View {
        HStack(spacing: 12) {
            
            Image(systemName: "creditcard")
                .font(.title2)
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "—")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(card.cardNumber?.maskedCardNumber() ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("Exp: \(card.expiration ?? "—")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
