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
    @State private var showBankLink = false
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false
    @State private var showFund = false

    init(container: AppContainer,
         onFinish: @escaping () -> Void,
         onSkip: @escaping () -> Void) {
        self.container = container
        self.onFinish = onFinish
        self.onSkip = onSkip
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            sparkleDecorations

            VStack(spacing: 0) {
                Spacer(minLength: Spacing.xxl)

                RegistrationCelebrationHero()
                    .frame(maxHeight: 190)
                    .padding(.bottom, Spacing.lg)
                // no .clipped() — would cut the balloon's −12° tilt corners

                VStack(spacing: Spacing.xl) {
                    Text("Your account\u{2019}s ready! Let\u{2019}s movo.")
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
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)

                Spacer(minLength: Spacing.xl)

                ctaFooter
            }
            .padding(.top, Spacing.md)
        }
        .background(Color.movo.background)
        .navigationBarHidden(true)
        // "Fund My Account" → link a bank via Plaid (link-only; success screen shows
        // "Done"). When the link succeeds, advance into the onboarding fund step.
        .sheet(isPresented: $showBankLink, onDismiss: {
            // Start Plaid only after the info sheet is fully gone.
            if continueToPlaid {
                continueToPlaid = false
                startPlaidFlow = true
            }
        }) {
            BankLinkedInfoScreen(onContinue: { continueToPlaid = true })
                .presentationDetents([.height(500)])
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
            onDone: { showFund = true }
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

    private var ctaFooter: some View {
        VStack(spacing: Spacing.xl) {
            Button(action: { showBankLink = true }) {
                Text("Fund My Account")
            }
            .buttonStyle(MovoPrimaryButtonStyle())

            Button {
                onSkip()
            } label: {
                Text("Skip for now")
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sparkle decorations

private extension KYCSuccessView {

    var sparkleDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Top-left cluster
                sparkle(size: 28).position(x: 40,      y: 80)
                sparkle(size: 16).position(x: 80,      y: 50)
                sparkle(size: 12).position(x: 30,      y: 130)

                // Top-right cluster
                sparkle(size: 24).position(x: w - 40,  y: 70)
                sparkle(size: 14).position(x: w - 75,  y: 40)
                sparkle(size: 10).position(x: w - 30,  y: 120)

                // Bottom-left cluster
                sparkle(size: 20).position(x: 50,      y: h - 160)
                sparkle(size: 12).position(x: 25,      y: h - 200)

                // Bottom-right cluster
                sparkle(size: 22).position(x: w - 50,  y: h - 170)
                sparkle(size: 13).position(x: w - 80,  y: h - 210)
                sparkle(size: 9) .position(x: w - 25,  y: h - 230)
            }
        }
        .allowsHitTesting(false)
    }

    func sparkle(size: CGFloat) -> some View {
        Text("✦")
            .font(.system(size: size))
            .foregroundColor(Color.movo.textTertiary.opacity(0.85))
    }
}
