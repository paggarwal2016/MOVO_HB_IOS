//
//  KYCSuccessView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 28/04/26.
//

import SwiftUI

struct KYCSuccessView: View {

    let container: AppContainer
    let onFinish: () -> Void
    let onSkip: () -> Void

    @StateObject private var plaidVM: PlaidAchViewModel
    @StateObject private var vCardVM: VCardViewModel
    @StateObject private var savingVM: SavingsAccountViewModel
    /// Apple Wallet result →  Bank link  →  Plaid link  →  Fund  →  Finish
    /// Continues once the shared activation flow's "All Set" screen calls `onAllSet`.
    @State private var showBankLink = false
    /// Bank link →  Plaid link
    /// Set when the user taps "Continue" on `BankLinkedInfoScreen`; consumed in
    /// that sheet's `onDismiss` so Plaid presents only after it's fully gone.
    @State private var continueToPlaid = false
    /// Bank link →  Plaid link
    @State private var startPlaidFlow = false
    /// Plaid link →  Fund
    @State private var showFund = false
    /// Primary account →  Activation  →  PIN entry →  SDK activation  →  Apple Wallet result
    /// Triggers the shared activation flow attached to this view's body.
    @State private var startCardActivation = false
    /// Primary account id resolved from `savingVM`, fed into the shared activation flow.
    @State private var activationAccountId: Int? = nil
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
        .virtualCardActivationFlow(
            vCardVM: vCardVM,
            plaidVM: plaidVM,
            isActive: $startCardActivation,
            accountId: activationAccountId,
            // Apple Wallet result →  Bank link
            onAllSet: { showBankLink = true },
            onRequiresSupport: { finishToDashboard() },
            allSetContent: { allSetScreen in
                AnyView(
                    allSetScreen
                        // Bank link
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
                        // Bank link →  Plaid link →  Fund
                        .plaidLinkFlow(
                            isActive: $startPlaidFlow,
                            plaidVM: plaidVM,
                            container: container,
                            allowFunding: false,
                            onDone: { showFund = true },
                            onCancel: { finishToDashboard() }
                        )
                        // Fund →  Finish
                        .fullScreenCover(isPresented: $showFund) {
                            FundAccountView(
                                container: container,
                                mode: .onboardingDeposit,
                                onSuccess: { finishToDashboard() }
                            )
                        }
                )
            }
        )
    }

    // Finish — collapses the entire Activation → Bank link → Plaid link → Fund
    // stack back to the Dashboard in one non-animated step.
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
            startCardActivation = false
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
        activationAccountId = primaryId
        startCardActivation = true
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
