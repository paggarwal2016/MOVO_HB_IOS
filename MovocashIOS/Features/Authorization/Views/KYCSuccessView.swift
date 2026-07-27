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
    @State private var cardActivated = false
    @State private var activatePrimaryAccountId = 0
    @State private var showAllSet = false
    @State private var pendingBankLink = false
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
        // "Activate Card" → create (activate) the user's cash card. On success we
        // dismiss the sheet and, in onDismiss, show the activation alert whose
        // action runs the original fund flow (showBankLink).
        .fullScreenCover(isPresented: $showActivateCard, onDismiss: {
            guard cardActivated else { return }
            cardActivated = false
            // Show the "You're all set!" confirmation (replaces the old alert).
            showAllSet = true
        }) {
            CreateCashCardView(
                vm: vCardVM,
                primaryAccountId: activatePrimaryAccountId,
                title: "Set your card PIN",
                mode: .activate,
                onClose: { showActivateCard = false },
                onActivated: {
                    cardActivated = true
                    showActivateCard = false
                }
            )
        }
        // Activation confirmation → continue to the bank-link fund step.
        .fullScreenCover(isPresented: $showAllSet, onDismiss: {
            if pendingBankLink {
                pendingBankLink = false
                showBankLink = true
            }
        }) {
            VirtualCardAllSetView(
                message: "Your virtual card is activated and ready to use.",
                onDone: {
                    pendingBankLink = true
                    showAllSet = false
                }
            )
        }
        // "Fund My Account" (alert action) → link a bank via Plaid (link-only; success
        // screen shows "Done"). When the link succeeds, advance into the onboarding fund step.
        .sheet(isPresented: $showBankLink, onDismiss: {
            // Start Plaid only after the info sheet is fully gone.
            if continueToPlaid {
                continueToPlaid = false
                startPlaidFlow = true
            } else {
                finishToDashboard()
            }
        }) {
            BankLinkedInfoScreen(
                onContinue: { continueToPlaid = true },
                // xmark → seamless: drop the sheet AND swap to the Dashboard in one
                // non-animated transaction, so the user never sees this sheet slide
                // away or the KYC screen behind it (no double-dismiss).
                onClose: {
                    var tx = SwiftUI.Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        showBankLink = false
                        finishToDashboard()
                    }
                }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Color.movo.cardSurface)
        }
        // After Plaid links and the success screen is dismissed ("Done"),
        // advance into the onboarding fund step.
        .plaidLinkFlow(
            isActive: $startPlaidFlow,
            plaidVM: plaidVM,
            container: container,
            allowFunding: false,
            onDone: { showFund = true },
            onCancel: { onFinish() }
        )
        // The onboarding fund step. Self-loads from/to accounts and lands on the
        // dashboard on success or back.
        .fullScreenCover(isPresented: $showFund) {
            FundAccountView(
                container: container,
                mode: .onboardingDeposit,
                onSuccess: {
                    showFund = false
                    onFinish()
                }
            )
        }
    }

    /// Finishes onboarding and lands on the Dashboard. Guarded so it runs at most
    /// once even though the bank-link close is observed in both onClose and onDismiss.
    private func finishToDashboard() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }

    /// Resolves the primary savings account, then presents the "Activate Card"
    /// (Create Cash Card) sheet. The card is created against the primary account.
    private func startActivateCard() {
        Task {
            SpinnerView.showFullScreen()
            await savingVM.loadAccounts()
            SpinnerView.hideFullScreen()
            guard let primaryId = savingVM.accountList?.data.accounts
                .first(where: { $0.isPrimary })?.id else {
                AlertManager.shared.showError("Unable to find your account. Please try again.")
                return
            }
            activatePrimaryAccountId = primaryId
            showActivateCard = true
        }
    }

    private var ctaFooter: some View {
        VStack(spacing: Spacing.xl) {
            Button(action: { startActivateCard() }) {
                Text("Set Your Card PIN")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
