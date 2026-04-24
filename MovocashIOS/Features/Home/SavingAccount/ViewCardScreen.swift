//
//  ViewCardScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import SwiftUI

struct ViewCardScreen: View {
    
    @Binding var isPresented: Bool
    let accountId: Int
    
    @StateObject private var vm: VCardViewModel

    init(isPresented: Binding<Bool>, accountId: Int, container: AppContainer) {
        _isPresented = isPresented
        self.accountId = accountId
        _vm = StateObject(wrappedValue: container.makeVCardViewModel())
    }
    @State private var card: VCardsList?
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsList?
    @State private var showAddCard = false
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.state == .loading {
                    SpinnerView()
                } else if let card {
                    CustomCardView(
                        title: "MOVO.",
                        card: card,
                        vm: vm,
                        showCardDetail: $showCardDetail,
                        revealedCard: $revealedCard
                    )
                } else {
                    EmptyStateView(
                        image: "creditcard",
                        title: "No Card",
                        description: "Card is not available."
                    )
                }
            }
            .navigationTitle("View Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(Color.primary)
                        .fontWeight(.semibold)
                }
            }
            .pinInputAlert(
                isPresented: $showAddCard,
                title: "Activate Card",
                message: "In order to activate card you need to create 4 digit PIN",
                pinPlaceholder: "4-digit PIN",
                confirmPlaceholder: "Re-enter PIN",
                config: TextInputAlertConfig(primaryLabel: "Activate",
                                             secondaryLabel: "Cancel"),
                style: .center,
                onCreate: { pin in
                    Task { await addCard(pin: pin) }
                }
            )
            .overlay { overlayContent }
        }
        .task { await loadCard() }
    }
        
    @ViewBuilder
    private var overlayContent: some View {
        if showCardDetail, let revealed = revealedCard {
            dimmedOverlay { showCardDetail = false } content: {
                VirtualCardDetailPopupView(card: revealed, isPresented: $showCardDetail)
                    .padding(.horizontal, 15)
            }
        }
    }
    
    private func loadCard() async {
        do { card = try await vm.getVCardPrimary()?.data?.first } catch {}
    }
    
    private func addCard(pin: String) async {
        do {
            card = try await vm.postVCard(request: VCardsRequest(pin: pin, accountId: accountId, userAction: "VCARD_CREATION"))
            ToastManager.shared.show("Success.", style: .success, position: .bottom)
        } catch {}
    }
}
