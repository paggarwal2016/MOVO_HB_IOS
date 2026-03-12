//
//  DashboardView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 04/03/26.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var vm = VCardViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager
    )
    @State private var card: VCardsResponse?
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsResponse?
    
    var body: some View {
        VStack(spacing: 0) {
            UserHeaderView {
                Task {
                    AppContainer.lockManager.logout()
                    await sessionManager.logout(appState: appState)
                }
            }
                        
            Group {
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
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if showCardDetail, let revealed = revealedCard {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { showCardDetail = false }
                    
                    CardDetailPopupView(card: revealed, isPresented: $showCardDetail)
                        .padding(.horizontal, 15)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .task { await loadCard() }
        .onAppear { showCardDetail = false }
    }
    
    private func loadCard() async {
        do { card = try await vm.getVCard() } catch {}
    }
}

