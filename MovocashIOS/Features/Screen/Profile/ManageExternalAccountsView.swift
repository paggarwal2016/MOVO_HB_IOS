//
//  ManageExternalAccountsView.swift
//  MovocashIOS
//

import SwiftUI

struct ManageExternalAccountsView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @ObservedObject var achVM: ACHViewModel
    let primaryAccount: SavingsAccountInfo?
    let container: AppContainer

    @StateObject private var plaidVM: PlaidAchViewModel

    @State private var showWithdraw = false
    @State private var isLinkedAccountLoading = false

    // Bank-link success flow
    @State private var showBankLinkedSuccess = false
    @State private var newlyLinkedAccount: ACHAccount? = nil
    @State private var showBankLinkedInfo = false
    // Set when the user taps "Continue" on the info sheet; consumed in onDismiss
    // to start the Plaid flow once the sheet is gone.
    @State private var continueToPlaid = false
    @State private var startPlaidFlow = false

    init(achVM: ACHViewModel, primaryAccount: SavingsAccountInfo?, container: AppContainer) {
        self.achVM = achVM
        self.primaryAccount = primaryAccount
        self.container = container
        _plaidVM = StateObject(wrappedValue: container.makePlaidACHViewModel())
    }

    private var canWithdraw: Bool {
        !achVM.accounts.isEmpty && primaryAccount != nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()

            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        if achVM.accounts.isEmpty {
                            emptyState
                        } else {
                            accountsSection
                        }
                        connectBankRow
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 160)
                }
            }

            StatusBarScrim()

            if !achVM.accounts.isEmpty {
                withdrawButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
            }

            if isLinkedAccountLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
                SpinnerView()
            }
        }
        .background(Color.movo.background.ignoresSafeArea())
        .navigationDestination(isPresented: $showWithdraw) {
            if let primary = primaryAccount {
                FundAccountView(
                    container: container,
                    initialAccounts: achVM.accounts,
                    primaryAccount: primary,
                    mode: .profile,
                    onSuccess: {
                        Task {
                            isLinkedAccountLoading = true
                            await achVM.fetchAccounts()
                            isLinkedAccountLoading = false
                        }
                    }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
            }
        }
        // MARK: - Bank Linked Success
        // Presented after a successful Plaid link from connectBankRow.
        //
        // Navigation pattern: set showWithdraw = true BEFORE dismissing the cover
        // so SwiftUI pushes FundAccountView into the navigation stack in the same
        // render pass. The cover dismisses and FundAccountView is already waiting
        // behind it — no onDismiss closure or timing hacks needed.
        .fullScreenCover(isPresented: $showBankLinkedSuccess) {
            BankLinkedSuccessScreen(
                account: newlyLinkedAccount,
                onDone: {
                    if primaryAccount != nil {
                        showWithdraw = true
                    }
                    showBankLinkedSuccess = false
                }
            )
        }
        .sheet(isPresented: $showBankLinkedInfo, onDismiss: {
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
        .plaidLinkFlow(
            isActive: $startPlaidFlow,
            plaidVM: plaidVM,
            container: container,
            primaryAccount: primaryAccount,
            allowFunding: false,
            onLinked: { account in
                // Bind immediately for an instant list update, then refresh in the
                // background so the row gets the real balance / achAccountId. The
                // success screen is already on-screen, so this never blocks the UI.
                achVM.addLinkedAccount(account)
                Task { await achVM.fetchAccounts() }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            // Pop the withdraw push (FundAccountView) so the profile stack doesn't
            // keep it behind the dashboard tab the user is being taken to.
            showWithdraw = false
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Linked Accounts")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(achVM.accounts, id: \.achAccountId) { account in
                accountCard(account)
            }
        }
    }

    // MARK: - Account Card

    private func accountCard(_ account: ACHAccount) -> some View {
        HStack(spacing: Spacing.md) {

            // Bank logo
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(account.logoImage != nil ? Color(.systemBackground) : Color.movo.elevated)
                    .frame(width: 44, height: 44)
                if let logo = account.logoImage {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                } else {
                    Image(systemName: "building.columns")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.movo.textSecondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .strokeBorder(Color.movo.border, lineWidth: account.logoImage != nil ? Stroke.hairline : 0)
            )

            // Account info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(account.institutionName)
                        .textStyle(Typography.body)
                        .foregroundColor(Color.movo.textPrimary)
                    if account.isDefault {
                        StatusPill("PRIMARY", variant: .accent)
                    }
                }
                Text("\(account.accountName) · ••\(account.accountNumber.suffix(4))")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
                if account.plaidAccountBalance > 0 {
                    Text(account.formattedBalance)
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: Spacing.sm) {
                if !account.isDefault {
                    Button {
                        Task {
                            isLinkedAccountLoading = true
                            await achVM.updateAccount(id: account.achAccountId)
                            await achVM.fetchAccounts()
                            isLinkedAccountLoading = false
                        }
                    } label: {
                        Image(systemName: "star")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.movo.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.movo.elevated,
                                        in: RoundedRectangle(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    AlertManager.shared.showConfirmation(
                        title: "Remove Account",
                        message: "Are you sure you want to remove \(account.institutionName) - \(account.accountName)?",
                        onConfirm: {
                            Task {
                                isLinkedAccountLoading = true
                                await achVM.deleteAccount(id: account.achAccountId)
                                await achVM.fetchAccounts()
                                isLinkedAccountLoading = false
                            }
                        }
                    )
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.movo.danger)
                        .frame(width: 36, height: 36)
                        .background(Color.movo.dangerTint,
                                    in: RoundedRectangle(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.rowPaddingVertical)
        .padding(.horizontal, Spacing.lg)
        .background(Color.movo.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
        )
    }

    // MARK: - Connect Bank Row

    private var connectBankRow: some View {
        Button {
            showBankLinkedInfo = true
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.movo.accentTint)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.movo.accent)
                }
                Text(plaidVM.state == .loading ? "Connecting..." : "Link your external account")
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.movo.accent)
            }
            .padding(.vertical, Spacing.rowPaddingVertical)
            .padding(.horizontal, Spacing.lg)
            .background(Color.movo.surface, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .disabled(plaidVM.state == .loading)
    }

    // MARK: - Withdraw Button
    private var withdrawButton: some View {
        Button {
            showWithdraw = true
        } label: {
            HStack {
                Spacer()
                Text("Withdraw Funds")
                    .textStyle(Typography.body)
                    .foregroundColor(Color.movo.textPrimary)
                Spacer()
            }
            .padding(.vertical, Spacing.lg)
            .background(Color.movo.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.movo.elevated)
                    .frame(width: 72, height: 72)
                Image(systemName: "building.columns")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Color.movo.textTertiary)
            }
            VStack(spacing: Spacing.xs) {
                Text("No linked accounts")
                    .textStyle(Typography.cardHero)
                    .foregroundColor(Color.movo.textPrimary)
                Text("Link a bank account from your profile\nto get started.")
                    .textStyle(Typography.subtitle)
                    .foregroundColor(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
