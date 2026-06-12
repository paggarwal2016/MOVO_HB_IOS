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
    @State private var isLoaded = false
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsList?
    @State private var showAddCard = false
    
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
                                .foregroundStyle(Color.movo.accent)
                                .fontWeight(.semibold)
                        }
                    }
            }
            
            if vm.state == .loading {
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
                Task { await addCard(nickname: "", pin: pin) }
            }
        )
        .overlay { overlayContent }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            showAddCard = false
            showCardDetail = false
            isPresented = false
        }
        .task {
            await loadCard()
        }
    }
    
    @ViewBuilder
    private var vcardSection: some View {
        switch vm.state {
        case .loading where card == nil:
            CardSkeletonView()
                .padding(.horizontal, Spacing.lg)
        default:
            if let card {
                CustomCardView(
                    title: "MOVO.",
                    card: card,
                    vm: vm,
                    showCardDetail: $showCardDetail,
                    revealedCard: $revealedCard
                )
                
                PrimaryButton(title: "Activate your card") {
                    showAddCard = true
                }
                .padding()
                .padding(.top, 40)
            } else if isLoaded {
                emptyCardState
            }
        }
    }
    
    private var emptyCardState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.movo.textSecondary)
            Text("No Card Yet")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
        do { card = try await vm.getVCardPrimary()?.data } catch {}
    }
    
    private func addCard(nickname: String, pin: String) async {
        do {
            card = try await vm.postVCard(request: VCardsRequest(pin: pin, accountId: accountId, userAction: "VCARD-ACTIVATE"))
            ToastManager.shared.show("Success.", style: .success, position: .bottom)
            showAddCard = false
        } catch {}
    }
}



