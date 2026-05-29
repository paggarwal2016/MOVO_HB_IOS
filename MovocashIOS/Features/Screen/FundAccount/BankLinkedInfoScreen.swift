//
//  BankLinkedInfoScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 27/05/26.
//

import SwiftUI

struct BankLinkedInfoScreen: View {

    @Environment(\.dismiss) private var dismiss
    let container: AppContainer
    @ObservedObject var plaidVM: PlaidAchViewModel
    var primaryAccount: SavingsAccountInfo? = nil
    var allowFunding: Bool = true
    var onSuccess: () -> Void = {}

    @State private var isConnecting = false
    @State private var fetchedAchAccounts: [ACHAccount] = []
    @State private var showSuccessScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            
            HStack {
                Spacer()
                CircularNavButton(systemName: "xmark") { dismiss() }
                    .accessibilityLabel("Close")
                    .padding(.leading, Spacing.md)
            }
            .padding(.top, Spacing.lg)

            // Header — logos + close on one balanced row
            HStack(alignment: .center, spacing: 0) {

                // MOVO tile
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.elevated)
                    .frame(width: 48, height: 48)
                    .overlay(
                        MovoMVSymbol()
                            .frame(width: 28, height: 28)
                    )
                
                Spacer()

                // Dot connector — fills space between the two tiles
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.movo.border)
                            .frame(width: i == 2 ? 4 : 3, height: i == 2 ? 4 : 3)
                            .opacity(i == 2 ? 0.6 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()

                // Plaid tile
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(Color.movo.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("plaid")
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)
                    )
               
            }

            // Title
            Text("MOVO partners with Plaid to connect your accounts")
                .textStyle(Typography.heroTitle)
                .foregroundColor(Color.movo.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Feature rows
            VStack(alignment: .leading, spacing: Spacing.xl) {
                featureRow(
                    icon: "checkmark.shield.fill",
                    title: "Trusted",
                    description: "Plaid connects to 12,000+ banks and 300M+ people across the US."
                )
                featureRow(
                    icon: "lock.fill",
                    title: "Secure",
                    description: "Your data is encrypted with 256-bit security. MOVO can't see your passwords."
                )
            }

            // Footer
            disclaimerText()

            // Continue CTA
            Button(isConnecting || plaidVM.state == .loading ? "Connecting..." : "Continue") {
                Task {
                    isConnecting = true
                    defer { isConnecting = false }

                    // Step 1 — Show spinner; yield one run-loop cycle so UIKit
                    //          actually renders it before the next sync work runs.
                    SpinnerView.showFullScreen()
                    await Task.yield()

                    do {
                        try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
                    } catch {
                        SpinnerView.hideFullScreen()
                        AlertManager.shared.showError("Unable to initialize. Please try again.")
                        return
                    }

                    // Step 2 — Hide spinner BEFORE Plaid SDK presents its own UI
                    SpinnerView.hideFullScreen()

                    // Step 3 — Plaid Link flow (SDK owns the screen from here)
                    await plaidVM.startPlaidLink()

                    // Step 4 — Account linked: show spinner, fetch fresh ACH list,
                    //          then open FundAccountView directly.
                    if plaidVM.linkedAccount != nil {
                        SpinnerView.showFullScreen()
                        await Task.yield()
                        let response = try? await container.network.request(AchAPI.getAccounts) as ACHResponse
                        SpinnerView.hideFullScreen()
                        fetchedAchAccounts = response?.achAccounts ?? []
                        // Always show the success screen so the user sees the
                        // linked-account confirmation. BankLinkedSuccessScreen
                        // handles the "Add funds" → FundAccountView step itself
                        // when container + primaryAccount are provided.
                        showSuccessScreen = true
                    }
                }
            }
            .buttonStyle(MovoPrimaryButtonStyle())
            .disabled(isConnecting || plaidVM.state == .loading)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xxl)
        .onDisappear {
            // Safety cleanup — ensures the spinner is never stranded if the
            // sheet is dismissed mid-flow (e.g. force-swipe while connecting).
            SpinnerView.hideFullScreen()
        }
        // MARK: - BankLinkedSuccessScreen
        // allowFunding=true  → "Add funds" CTA → FundAccountView (fund flow)
        // allowFunding=false → "Done" CTA → dismisses back to dashboard (link-only flow)
        .fullScreenCover(isPresented: $showSuccessScreen) {
            BankLinkedSuccessScreen(
                account: fetchedAchAccounts.first,
                onDone: {
                    showSuccessScreen = false
                    onSuccess()
                    dismiss()
                },
                container: allowFunding ? container : nil,
                primaryAccount: allowFunding ? primaryAccount : nil,
                linkedAccounts: fetchedAchAccounts
            )
        }
    }

    // MARK: - Disclaimer

    private func disclaimerText() -> some View {
        (
            Text("By selecting Continue, you agree to the ")
                .foregroundColor(Color.movo.textSecondary)
            + Text("Plaid End User Privacy Policy")
                .foregroundColor(Color.movo.textSecondary)
                .underline(true, color: Color.movo.borderStrong)
            + Text(".")
                .foregroundColor(Color.movo.textTertiary)
        )
        .font(.system(size: 11, weight: .regular))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            if let url = URL(string: "https://www.herringbank.com") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.movo.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)

                Text(description)
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}
