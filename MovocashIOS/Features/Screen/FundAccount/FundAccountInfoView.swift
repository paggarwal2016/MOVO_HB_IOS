//
//  FundAccountInfoView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/06/26.
//

import SwiftUI

struct FundAccountInfoView: View {

    let container: AppContainer
    var onSkip: () -> Void = {}
    var onFinish: () -> Void = {}

    @StateObject private var plaidVM: PlaidAchViewModel
    @State private var showBankLink = false
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false
    @State private var showFund = false

    init(container: AppContainer,
         onSkip: @escaping () -> Void = {},
         onFinish: @escaping () -> Void = {}) {
        self.container = container
        self.onSkip = onSkip
        self.onFinish = onFinish
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()
            
            VStack {

                Spacer()

                // MARK: Illustration
                FundAccountIllustration(size: 220)
                    .padding(.bottom, Spacing.huge)

                // MARK: Title
                Text("Fund your account")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)

                // MARK: Subtitle
                Text("Add money to send to family and friends, or spend anywhere.")
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)
                    .padding(.top, Spacing.sm)

                Spacer()

                // MARK: Buttons
                VStack(spacing: Spacing.xl) {
                    
                    Button(action: { showBankLink = true} ) {
                        Text("Fund account")
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

            }
        }
        .trackScreen(AnalyticsScreen.fundAccount)
        // "Fund account" → link a bank via Plaid (link-only; success screen shows
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
}







// MARK: - Illustration

struct FundAccountIllustration: View {
    
    var size: CGFloat = 220
    
    private var bankWidth: CGFloat { size * 0.34 }
    private var bankHeight: CGFloat { size * 0.34 }
    
    private var phoneWidth: CGFloat { size * 0.20 }
    private var phoneHeight: CGFloat { size * 0.34 }
    
    var body: some View {
        
        HStack(spacing: size * 0.08) {
            
            // MARK: Bank
            
            BankBuildingShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.movo.textPrimary.opacity(0.95),
                            Color.movo.textPrimary.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.012,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(
                    width: bankWidth,
                    height: bankHeight
                )
            
            // MARK: Connection
            
            VStack(spacing: 0) {
                
                Circle()
                    .stroke(
                        Color.movo.accent.opacity(0.75),
                        lineWidth: size * 0.01
                    )
                    .frame(
                        width: size * 0.06,
                        height: size * 0.06
                    )
                
                CurvedDottedLine()
                    .stroke(
                        Color.movo.textPrimary.opacity(0.35),
                        style: StrokeStyle(
                            lineWidth: size * 0.008,
                            lineCap: .round, dash: [4, 5]
                        )
                    )
                    .frame(
                        width: size * 0.15,
                        height: size * 0.10
                    )
            }
            
            // MARK: Phone
            
            PhoneShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.movo.textPrimary.opacity(0.95),
                            Color.movo.textPrimary.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.012,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(
                    width: phoneWidth,
                    height: phoneHeight
                )
                .overlay {
                    
                    // Fixed inner rectangle
                    
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            Color.movo.accent.opacity(0.55),
                            lineWidth: 1
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.movo.accent.opacity(0.12))
                        )
                        .frame(
                            width: size * 0.10,
                            height: size * 0.06
                        )
                }
        }
        .frame(width: size, height: size * 0.45)
    }
}



// MARK: - Phone Shape

struct PhoneShape: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        let cornerRadius: CGFloat = rect.width * 0.18
        
        // Outer body
        
        path.addRoundedRect(
            in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height
            ),
            cornerSize: CGSize(
                width: cornerRadius,
                height: cornerRadius
            )
        )
        
        // Speaker
        
        let speakerWidth = rect.width * 0.28
        let speakerHeight = rect.height * 0.03
        
        let speakerX = rect.midX - (speakerWidth / 2)
        let speakerY = rect.height * 0.09
        
        path.addRoundedRect(
            in: CGRect(
                x: speakerX,
                y: speakerY,
                width: speakerWidth,
                height: speakerHeight
            ),
            cornerSize: CGSize(width: 2, height: 2)
        )
        
        // Bottom line
        
        path.move(
            to: CGPoint(
                x: rect.width * 0.38,
                y: rect.height * 0.90
            )
        )
        
        path.addLine(
            to: CGPoint(
                x: rect.width * 0.62,
                y: rect.height * 0.90
            )
        )
        
        return path
    }
}



// MARK: - Bank Shape

struct BankBuildingShape: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // Roof
        
        path.move(to: CGPoint(x: w * 0.1, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
        
        // Inner roof
        
        path.move(to: CGPoint(x: w * 0.38, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.10))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.18))
        
        // Columns
        
        path.move(to: CGPoint(x: w * 0.25, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.8))
        
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.8))
        
        path.move(to: CGPoint(x: w * 0.75, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.8))
        
        // Base
        
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.86))
        
        return path
    }
}

// MARK: - Curved Dotted Line

struct CurvedDottedLine: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        path.move(
            to: CGPoint(
                x: 0,
                y: rect.height * 0.1
            )
        )
        
        path.addCurve(
            to: CGPoint(
                x: rect.width,
                y: rect.height * 0.9
            ),
            control1: CGPoint(
                x: rect.width * 0.25,
                y: rect.height * 0.9
            ),
            control2: CGPoint(
                x: rect.width * 0.7,
                y: rect.height * 0.1
            )
        )
        
        return path
    }
}
