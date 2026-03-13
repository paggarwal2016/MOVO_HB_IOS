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
    @EnvironmentObject var lockManager: AppLockManager
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var vm = VCardViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager)
    @State private var card: VCardsResponse?
    @State private var showCardDetail = false
    @State private var revealedCard: VCardsResponse?
    
    // MARK: - Saving
    @StateObject private var savingVM = SavingsAccountViewModel(
        network: AppContainer.shared.network,
        alertManager: AppContainer.shared.alertManager)
    @State private var savingsList: SavingsAccountListResponse?
    @State private var selectedAccount: SavingsAccountDetailsResponse?
    @State private var showAccountList = false
    @State private var showPriomaryAccountDetails = false
    private var displayAccount: SavingsAccountDetailsResponse? {
        selectedAccount ?? savingsList?.accounts.first(where: { $0.isPrimary })
    }
    
    var body: some View {
        
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                CustomHeaderView(userName: "Test", userImage: "user", onLogout: {
                    AlertManager.shared.showConfirmation(title: "Info", message: "Are you want to logout.", onConfirm:  {
                        Task {
                            AppContainer.lockManager.logout()
                            await sessionManager.logout(appState: appState)
                        }
                    })
                })
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - Balance Card
                        
                        if let account = displayAccount {
                            BalanceCardView(
                                account: account,
                                totalAvailableBalance: savingsList?.totalAvailableBalance ?? 0.00,
                                onPrimaryTap: { showPriomaryAccountDetails = true }
                            )
                            
                            PrimaryButton(title: "View Cash Accounts", backgroundColor: .gray.opacity(0.1), textColor: .black) {
                                showAccountList = true
                            }
                            .padding()
                            .frame(height: 60)
                        } else if savingVM.state == .loading {
                            CardSkeletonView()
                        }
                        
                        // MARK: - VCard
                        
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
                        Spacer()
                    }
                    .padding(.top, 16)
                }
                
            }
            
        }
        
        .overlay {
            if showCardDetail, let revealed = revealedCard {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { showCardDetail = false }
                    
                    VirtualCardDetailPopupView(card: revealed, isPresented: $showCardDetail)
                        .padding(.horizontal, 15)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            } else {
                if showPriomaryAccountDetails, let display = displayAccount {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture { showPriomaryAccountDetails = false }
                        
                        SavingActDetailPopupView(account: display, isPresented: $showPriomaryAccountDetails)
                            .padding(.horizontal, 15)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    
                }
            }
        }
        
        .sheet(isPresented: $showAccountList) {
            AccountListSheetView(
                selectedAccount: $selectedAccount,
                isPresented: $showAccountList
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: lockManager.state) {
            guard lockManager.state == .unlocked else { return }
            await loadData()
        }
        .onAppear { showCardDetail = false }
    }
    
    // MARK: - Private Functions
    
    private func loadData() async {
        async let savings: () = loadSavings()
        async let vcard: () = loadCard()
        await savings
        await vcard
    }
    
    private func loadSavings() async {
        do { savingsList = try await savingVM.getSavingAccountList() } catch {}
    }
    
    private func loadCard() async {
        do { card = try await vm.getVCard() } catch {}
    }
}

