//
//  BankLinkedSuccessScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 27/05/26.
//

import SwiftUI

struct BankLinkedSuccessScreen: View {

    var account: ACHAccount?
    var onDone: () -> Void = {}

    // Optional dependencies — supplied by BankLinkedInfoScreen so tapping
    // "Add funds" pushes FundAccountView directly rather than dismissing.
    // ManageExternalAccountsView does NOT pass these (it owns its own
    // navigation), so it falls back to the existing onDone path.
    var container: AppContainer? = nil
    var primaryAccount: SavingsAccountInfo? = nil
    var linkedAccounts: [ACHAccount] = []

    @State private var showFundAccount = false

    // MARK: - Derived display values

    private var institutionName: String {
        account?.institutionName ?? "Bank"
    }

    private var initials: String {
        String(institutionName.prefix(2)).uppercased()
    }

    private var accountName: String {
        account?.accountName ?? "Checking"
    }

    private var maskedNumber: String {
        account.map { "••••\($0.accountNumber.suffix(4))" } ?? "••••••••"
    }

    private var balanceText: String {
        account?.formattedBalance ?? ""
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            // Theme background — adapts to system light / dark
            Color.movo.background
                .ignoresSafeArea()

            // Accent glow overlay
            RadialGradient(
                colors: [Color.movo.accent.opacity(0.20), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer().frame(height: Spacing.huge + Spacing.xxxl) // 72pt — icon in upper third

                // MARK: - Success Icon

                ZStack {
                    Circle()
                        .stroke(Color.movo.border, lineWidth: Stroke.thick)
                        .frame(width: 130, height: 130)

                    Circle()
                        .stroke(Color.movo.accentBorder, lineWidth: Stroke.thin)
                        .frame(width: 160, height: 160)

                    // Orbit dots
                    Circle()
                        .fill(Color.movo.accent.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: -80, y: -10)

                    Circle()
                        .fill(Color.movo.accent.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: 82, y: -25)

                    Circle()
                        .fill(Color.movo.accent.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: 70, y: 55)

                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(Color.movo.accent)
                }

                Spacer().frame(height: Spacing.huge)

                // MARK: - Title

                Text("\(institutionName) account linked")
                    .textStyle(Typography.heroTitle)
                    .foregroundColor(Color.movo.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)

                Spacer().frame(height: Spacing.md)

                // MARK: - Subtitle

                Text("You can now move money between your bank and MOVO. Transfers take 1–3 business days.")
                    .textStyle(Typography.cardHero)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xxxl)

                Spacer().frame(height: Spacing.xxxl)

                // MARK: - Bank Card

                HStack(spacing: Spacing.lg) {

                    // Institution logo or initials tile
                    if let logo = account?.logoImage {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    } else {
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .fill(Color.movo.accentTint)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.xl)
                                    .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                            )
                            .frame(width: 54, height: 54)
                            .overlay(
                                Text(initials)
                                    .textStyle(Typography.cardTitle)
                                    .foregroundColor(Color.movo.accent)
                            )
                    }

                    // Account info
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(accountName)
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)

                        Text([balanceText, maskedNumber]
                            .filter { !$0.isEmpty }
                            .joined(separator: "  "))
                            .textStyle(Typography.subtitle)
                            .foregroundColor(Color.movo.textTertiary)
                    }

                    Spacer()

                    // Linked badge
                    Text("LINKED")
                        .textStyle(Typography.eyebrow)
                        .foregroundColor(Color.movo.accent)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Capsule().fill(Color.movo.accentTint))
                        .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
                }
                .padding(Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sheet)
                        .fill(Color.movo.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sheet)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
                .padding(.horizontal, Spacing.xl)

                Spacer()

                // MARK: - Add Funds CTA

                Button {
                    if container != nil && primaryAccount != nil {
                        showFundAccount = true   // navigate into FundAccountView
                    } else {
                        onDone()                 // fallback — ManageExternalAccountsView path
                    }
                } label: {
                    Text("Add funds")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        // MARK: - FundAccountView
        // Presented on top of this screen so the user enters the transfer
        // flow immediately. onDone is called once the transfer completes,
        // letting BankLinkedInfoScreen dismiss the whole chain back to Dashboard.
        .fullScreenCover(isPresented: $showFundAccount) {
            if let c = container, let primary = primaryAccount {
                FundAccountView(
                    container: c,
                    initialAccounts: linkedAccounts,
                    primaryAccount: primary,
                    onSuccess: {
                        showFundAccount = false
                        onDone()    // signals BankLinkedInfoScreen to clean up
                    }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    BankLinkedSuccessScreen()
}
