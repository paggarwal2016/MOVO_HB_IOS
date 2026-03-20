//
//  ViewCardScreen.swift
//  MovocashIOS
//
//  Created by Movo Developer on 17/03/26.
//

import SwiftUI

struct ViewCardScreen: View {
    
    @Binding var isPresented: Bool

    @StateObject private var savingVM: SavingsAccountViewModel
    @StateObject private var vm: VCardViewModel

    init(
        isPresented: Binding<Bool>,
        savingVM: SavingsAccountViewModel = AppContainer.shared.makeSavingsAccountViewModel(),
        vm: VCardViewModel = AppContainer.shared.makeVCardViewModel()
    ) {
        _isPresented = isPresented
        _savingVM = StateObject(wrappedValue: savingVM)
        _vm = StateObject(wrappedValue: vm)
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
                                .foregroundStyle(AppColors.primary)
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
            message: "",
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
    
    @ViewBuilder
    private func dimmedOverlay(onDismiss: @escaping () -> Void, content: () -> some View) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private func loadCard() async {
        do { card = try await vm.getVCard() } catch {}
    }
    
    private func addCard(pin: String) async {
        do {
            card = try await vm.postVCard(request: VCardsRequest(pin: pin))
            ToastManager.shared.show("Success.", style: .success, position: .bottom)
        } catch {}
    }
}
