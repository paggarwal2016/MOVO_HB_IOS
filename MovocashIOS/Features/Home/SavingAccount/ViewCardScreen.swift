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

    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var vm: VCardViewModel

    init(isPresented: Binding<Bool>, accountId: Int, container: AppContainer) {
        _isPresented = isPresented
        self.accountId = accountId
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
        _vm = StateObject(wrappedValue: container.makeVCardViewModel())
    }
    @State private var card: VCardsResponse?
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsResponse?
    @State private var showAddCard = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                vcardSection
                
                if card != nil {
                    PrimaryButton(title: "Activate your card") {
                        showAddCard = true
                    }
                    .padding()
                    .padding(.top, 40)
                }
                                
                Spacer()
                    .navigationTitle("View Card")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isPresented = false }
                                .foregroundStyle(Color.primary)
                                .fontWeight(.semibold)
                        }
                    }
            }
            
            if savingVM.state == .loading {
                SpinnerView()
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
        .task {
            await loadCard()
        }
    }
    
    @ViewBuilder
    private var vcardSection: some View {
        switch vm.state {
        case .loading where card == nil:
            CardSkeletonView()
        default:
            if let card {
                CustomCardView(
                    title: "MOVO.",
                    card: card,
                    vm: vm,
                    showCardDetail: $showCardDetail,
                    revealedCard: $revealedCard
                )
            }
        }
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
        do { card = try await vm.getVCardPrimary() } catch {}
    }
    
    private func addCard(pin: String) async {
        do {
            card = try await vm.postVCard(request: VCardsRequest(pin: pin, accountId: accountId))
            ToastManager.shared.show("Success.", style: .success, position: .bottom)
        } catch {}
    }
}
