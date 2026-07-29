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
    @State private var showBankLink = false
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false
    @State private var showFund = false
    @State private var showActivateCard = false
    @State private var activatePrimaryAccountId = 0
    @State private var showAllSet = false
    /// Guards against `onFinish` firing more than once (the bank-link close is
    /// handled in both the sheet's onClose and its onDismiss).
    @State private var didFinish = false

    /// Measured frame of the celebration hero — fed to the background so its marks
    /// never overlap the hero.
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
                    // Measure a tight 116×116 anchor centered on the hero (mirrors the
                    // waitlist badge circle) so the marks' glow/exclusion stays compact
                    // instead of scaling to the full-width hero.
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
                // no .clipped() — would cut the balloon's −12° tilt corners

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
        // Preload the accounts silently when this screen appears (no spinner), so
        // "Activate Card" can resolve the primary account instantly.
        .task { await savingVM.loadAccounts() }
        // Registration activation flow — each screen is presented ON TOP of the
        // previous one (stacked); nothing below is dismissed until the flow ends.
        // Tapping X on Bank Linked Info calls finishToDashboard(), which swaps the
        // root to the Dashboard and tears the WHOLE stack down at once (no per-
        // screen dismiss animation).
        //
        // Level 1 — Create Cash Card (Set your card PIN).
        .fullScreenCover(isPresented: $showActivateCard) {
            CreateCashCardView(
                vm: vCardVM,
                primaryAccountId: activatePrimaryAccountId,
                title: "Set your card PIN",
                mode: .activate,
                showsNicknameField: false,
                fixedNickname: "MOVO Vault Card",
                showsCloseButton: false,
                onClose: { showActivateCard = false },
                // Present "You're all set!" ON TOP — do NOT dismiss this screen.
                onActivated: { showAllSet = true }
            )
            // Level 2 — "You're all set!" stacked over Create Cash Card.
            .fullScreenCover(isPresented: $showAllSet) {
                VirtualCardAllSetView(
                    title: "Your digital cash card is live!",
                    message: "Your MOVO card is ready to go. Add it to Apple Wallet or start spending right away.",
                    // Present Bank Linked Info ON TOP — do NOT dismiss this screen.
                    onDone: { showBankLink = true }
                )
                // Level 3 — Bank Linked Info stacked over "You're all set!".
                .sheet(isPresented: $showBankLink, onDismiss: {
                    // Continue → start Plaid once the sheet is gone. (The X finishes
                    // onboarding directly via onClose, so no else-branch here.)
                    if continueToPlaid {
                        continueToPlaid = false
                        startPlaidFlow = true
                    }
                }) {
                    BankLinkedInfoScreen(
                        onContinue: { continueToPlaid = true },
                        // X → finish onboarding: the root swaps to the Dashboard,
                        // collapsing the entire stack at once with no animation.
                        onClose: { finishToDashboard() }
                    )
                    .presentationDetents([.height(430)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(Radius.sheet)
                    .presentationBackground(Color.movo.cardSurface)
                }
                // Plaid link + onboarding fund step run ABOVE the "You're all set!"
                // screen (which stays presented), so they don't collide with the
                // outer cover. Both finish by landing on the Dashboard.
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
        // Swap the root to the Dashboard with animations disabled, so the entire
        // presentation stack (Create Cash Card → All Set → Bank Info) is removed in
        // one shot with no intermediate dismiss animation.
        var tx = SwiftUI.Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { onFinish() }
    }

    private func startActivateCard() {
        guard let primaryId = savingVM.accountList?.data.accounts
            .first(where: { $0.isPrimary })?.id else {
            AlertManager.shared.showError("Unable to find your account. Please try again.")
            return
        }
        activatePrimaryAccountId = primaryId
        showActivateCard = true
    }

    private var ctaFooter: some View {
        VStack(spacing: Spacing.xl) {
            Button(action: { startActivateCard() }) {
                Text("Set your card PIN")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
