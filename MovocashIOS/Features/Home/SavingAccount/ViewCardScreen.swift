//
//  ViewCardScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 17/03/26.
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
    
    var body: some View {
        ZStack {
            NavigationStack {
                vcardSection
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
}
