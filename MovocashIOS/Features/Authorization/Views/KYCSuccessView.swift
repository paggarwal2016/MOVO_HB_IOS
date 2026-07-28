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

//            Button {
//                onSkip()
//            } label: {
//                Text("Skip for now")
//                    .textStyle(Typography.body)
//                    .foregroundColor(Color.movo.textSecondary)
//            }
//            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
