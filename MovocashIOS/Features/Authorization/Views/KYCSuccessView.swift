//
//  KYCSuccessView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 28/04/26.
//

import SwiftUI

/// Wraps the resolved primary account id so it can drive `.fullScreenCover(item:)` —
/// binding the id directly into what's presented, rather than through a sibling
/// `@State` var set just before flipping a separate `isPresented` flag.
private struct ActivateCardAccount: Identifiable {
    let id: Int
}

struct KYCSuccessView: View {
    
    let container: AppContainer
    let onFinish: () -> Void
    let onSkip: () -> Void
    
    @StateObject private var plaidVM: PlaidAchViewModel
    @StateObject private var vCardVM: VCardViewModel
    @StateObject private var savingVM: SavingsAccountViewModel
    @State private var showBankLink = false
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false
    @State private var showFund = false
    @State private var activateCardAccount: ActivateCardAccount? = nil
    @State private var didFinish = false
    
    @State private var badgeFrame: CGRect = .zero
    
    init(container: AppContainer,
         onFinish: @escaping () -> Void,
         onSkip: @escaping () -> Void) {
        self.container = container
        self.onFinish = onFinish
        self.onSkip = onSkip
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
        _vCardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
    }
    
    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            FloatingMovoMarks(excludedCircle: badgeFrame)
            
            VStack(spacing: 0) {
                Spacer(minLength: Spacing.xxl)
                
                RegistrationCelebrationHero()
                    .frame(maxHeight: 190)
                    .overlay(
                        Color.clear
                            .frame(width: 116, height: 116)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: BadgeFramePreferenceKey.self,
                                        value: proxy.frame(in: .named("kycSuccess"))
                                    )
                                }
                            )
                    )
                    .padding(.bottom, Spacing.lg)
                
                VStack(spacing: Spacing.xl) {
                    Text("Your MOVO account\u{2019}s ready! Let\u{2019}s Movo.")
                        .textStyle(Typography.heroTitle)
                        .foregroundColor(Color.movo.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Text("Identity verified. Add money to send to family & friends \u{2014} or spend anywhere.")
                        .textStyle(Typography.subtitle)
                        .foregroundColor(Color.movo.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.xl)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)
                
                Spacer(minLength: Spacing.xl)
                
                ctaFooter
            }
            .padding(.top, Spacing.md)
        }
        .coordinateSpace(name: "kycSuccess")
        .onPreferenceChange(BadgeFramePreferenceKey.self) { badgeFrame = $0 }
        .background(Color.movo.background)
        .navigationBarHidden(true)
        .task { await savingVM.loadAccounts() }
        
        // Level 1 — Create Cash Card (Set your card PIN).
        .fullScreenCover(item: $activateCardAccount) { account in
            CreateCashCardView(
                vm: vCardVM,
                plaidVM: plaidVM,
                primaryAccountId: account.id,
                title: "Set your card PIN",
                mode: .activate,
                nicknameFieldLabel: "NICK NAME",
                fixedNickname: "MOVO Vault Card",
                isNicknameEditable: false,
                onClose: { activateCardAccount = nil },
                onActivationRequiresSupport: { finishToDashboard() }
            )
            // Bound directly to the ViewModel's flag — set by the SDK's wallet
            // provisioning notifications as soon as any of them fires, not after
            // CreateCashCardView's own `await activateVirtualCard(...)` resolves.
            .fullScreenCover(isPresented: $plaidVM.showVirtualCardAllSet) {
                VirtualCardAllSetView(
                    title: "Your digital cash card is live!",
                    message: allSetMessage,
                    onDone: {
                        plaidVM.showVirtualCardAllSet = false
                        showBankLink = true
                    }
                )
                .sheet(isPresented: $showBankLink, onDismiss: {
                    if continueToPlaid {
                        continueToPlaid = false
                        startPlaidFlow = true
                    }
                }) {
                    BankLinkedInfoScreen(
                        onContinue: { continueToPlaid = true },
                        onClose: { finishToDashboard() }
                    )
                    .presentationDetents([.height(430)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(Radius.sheet)
                    .presentationBackground(Color.movo.cardSurface)
                }
                .plaidLinkFlow(
                    isActive: $startPlaidFlow,
                    plaidVM: plaidVM,
                    container: container,
                    allowFunding: false,
                    onDone: { showFund = true },
                    onCancel: { finishToDashboard() }
                )
                .fullScreenCover(isPresented: $showFund) {
                    FundAccountView(
                        container: container,
                        mode: .onboardingDeposit,
                        onSuccess: { finishToDashboard() }
                    )
                }
            }
        }
    }
    
    private func finishToDashboard() {
        guard !didFinish else { return }
        didFinish = true
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            // Collapse every nested cover in THIS view before the root swaps away.
            // RootView replacing this whole subtree (appState.flow = .home) does not
            // reliably tear down fullScreenCovers still bound to this view's own
            // state — leaving an orphaned screen (e.g. CreateCashCardView) visible
            // underneath. Zeroing them here, in the same non-animated transaction as
            // the flow swap, ensures nothing is left presented.
            showFund = false
            startPlaidFlow = false
            showBankLink = false
            plaidVM.showVirtualCardAllSet = false
            activateCardAccount = nil
            onFinish()
        }
    }
    
    private func startActivateCard() {
        // `id == 0` is never a real account id — treat it the same as "not found yet"
        // rather than sending a bogus accountId through to the SDK/activation call.
        guard let primaryId = savingVM.accountList?.data.accounts
            .first(where: { $0.isPrimary })?.id, primaryId != 0 else {
            AlertManager.shared.showError("Unable to find your account. Please try again.")
            return
        }
        activateCardAccount = ActivateCardAccount(id: primaryId)
    }
    
    private var allSetMessage: String {
        switch plaidVM.walletProvisioningOutcome {
        case .activeButNotInWallet:
            return "Your Main MOVO card is live and ready to use. We couldn't add it to Apple Wallet just now — you can try again anytime from your Card screen."
        case .addedToWallet, .none:
            return "Your main MOVO card is live and in your Apple Wallet. Add money to start spending."
        }
    }
    
    private var ctaFooter: some View {
        VStack(spacing: Spacing.xl) {
            Button(action: { startActivateCard() }) {
                Text("Add to Apple Wallet")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
