//
//  KYCSuccessView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 28/04/26.
//

import SwiftUI

private struct ActivateCardAccount: Identifiable {
    let id: Int
}

private struct PendingActivation {
    let pin: String
    let accountId: Int
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
    @State private var pendingActivation: PendingActivation? = nil
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
                    .frame(maxHeight: 260)
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
                    .padding(.bottom, Spacing.md)
                // no .clipped() — would cut the balloon's −12° tilt corners

                VStack(spacing: Spacing.xs) {
                    Text("MOVOCASH")
                        .font(.system(size: 22, weight: .regular))
                        .tracking(8.8)
                        .foregroundColor(Color.movo.textPrimary)
                        .padding(.leading, 8.8)

                    Text("Powered by HyperBin\u{00AE}")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, Spacing.lg)

                 
                VStack(spacing: Spacing.xl) {
                    Text("You\u{2019}re in. Let\u{2019}s MOVO!")
                        .textStyle(Typography.sectionTitle)
                        .foregroundColor(Color.movo.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Add your Main MOVO card to Apple Wallet to tap and pay anywhere.")
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
        // `onDismiss` only fires once this cover has actually finished dismissing —
        // that's what launches the SDK, so it's never presented on top of (or falls
        // back to) this screen. See `launchPendingActivationIfNeeded()`.
        .fullScreenCover(item: $activateCardAccount, onDismiss: {
            launchPendingActivationIfNeeded()
        }) { account in
            CreateCashCardView(
                vm: vCardVM,
                plaidVM: plaidVM,
                primaryAccountId: account.id,
                title: "Set your Main MOVO card PIN",
                mode: .activate,
                nicknameFieldLabel: "NICK NAME",
                fixedNickname: "MOVO Vault Card",
                isNicknameEditable: false,
                onClose: { activateCardAccount = nil },
                onActivationRequiresSupport: { finishToDashboard() },
                onPinConfirmed: { pin in
                    pendingActivation = PendingActivation(pin: pin, accountId: account.id)
                    activateCardAccount = nil
                }
            )
        }
        .fullScreenCover(isPresented: $plaidVM.showVirtualCardAllSet) {
            VirtualCardAllSetView(
                title: "Your Main MOVO card is ready to use!",
                message: allSetMessage,
                onDone: {
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
                    onClose: { showBankLink = false }
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
    
    /// Fires from the Create Cash Card cover's `onDismiss` — i.e. strictly after that
    /// screen has finished dismissing — so the activation SDK is only ever presented
    /// with THIS screen behind it, never Create Cash Card.
    private func launchPendingActivationIfNeeded() {
        guard let pending = pendingActivation else { return }
        pendingActivation = nil
        Task {
            await plaidVM.activateVirtualCard(
                pin: pending.pin,
                accountId: pending.accountId,
                onRequiresSupport: { finishToDashboard() }
            )
            if plaidVM.state == .success {
                try? await KeychainManager.shared.save(
                    pending.pin, for: KeychainManager.Keys.cardPinForCurrentUser, protection: .backgroundSafe
                )
            }
        }
    }
    
    private func finishToDashboard() {
        guard !didFinish else { return }
        didFinish = true
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            showFund = false
            startPlaidFlow = false
            showBankLink = false
            plaidVM.showVirtualCardAllSet = false
            activateCardAccount = nil
            pendingActivation = nil
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
            return "We couldn\u{2019}t add it to Apple Wallet right now \u{2014} you can try again anytime from your Card screen."
        case .addedToWallet, .none:
            return "Your Main MOVO card has been added to Apple Wallet. Add money to start spending."
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
