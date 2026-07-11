//
//  PlaidLinkFlowModifier.swift
//  MovocashIOS
//
//  Drives the Plaid link flow from a PARENT screen so the originating
//  BankLinkedInfoScreen can be fully dismissed before Plaid is presented.
//

import SwiftUI

// MARK: - PlaidLinkFlowModifier

/// Runs the Plaid link flow on behalf of a parent screen.
///
/// When `isActive` flips to `true` (the parent sets it after the info sheet has
/// dismissed) the modifier:
///   1. configures the KYC SDK,
///   2. presents Plaid via `plaidVM.startPlaidLink()` — on a clean stack, since
///      the info sheet is already gone,
///   3. on success calls `onLinked(account)` and presents `BankLinkedSuccessScreen`,
///   4. calls `onDone` when the user finishes the success screen.
///
/// This keeps all three entry points (Manage External Accounts, Dashboard,
/// Onboarding) behaving identically without duplicating the flow.
struct PlaidLinkFlowModifier: ViewModifier {

    @ObservedObject var plaidVM: PlaidAchViewModel
    @Binding var isActive: Bool
    let container: AppContainer
    var primaryAccount: SavingsAccountInfo?
    var allowFunding: Bool
    var onLinked: (ACHAccount) -> Void
    var onDone: () -> Void

    // Item-driven presentation: the cover is built only once `linkedAccount` is
    // non-nil and receives that exact value. This closes the race that let the
    // isPresented-based cover render with a stale/nil account (the "FROM field
    // not loaded" bug), where the presentation flag and the account were two
    // separate @State writes.
    @State private var linkedAccount: ACHAccount?

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { active in
                guard active else { return }
                // Consume the trigger immediately so it fires exactly once.
                isActive = false
                Task { await runFlow() }
            }
            // `onDone` fires from the cover's onDismiss — i.e. only AFTER the
            // success screen has fully dismissed. This prevents the parent from
            // presenting its own screen (e.g. onboarding's FundAccountView) while
            // this cover is still dismissing, which would present on a churning
            // stack and cancel that screen's `.task` (leaving it unloaded).
            .fullScreenCover(item: $linkedAccount, onDismiss: { onDone() }) { account in
                BankLinkedSuccessScreen(
                    account: account,
                    onDone: { linkedAccount = nil },
                    container: allowFunding ? container : nil,
                    showBalance: false
                )
            }
            // Collapse this cover (and the FundAccountView cover nested inside the
            // success screen) when any descendant posts .returnToDashboard — e.g.
            // after a successful fund transfer. Without this the success cover stays
            // up and the user never lands back on the dashboard.
            .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
                linkedAccount = nil
            }
    }

    @MainActor
    private func runFlow() async {
        // Show the spinner for the whole preparation — SDK configure, token
        // refresh, and link-token fetch — and keep it up until Plaid's own UI
        // actually appears (the `.open` callback). Hiding it earlier caused the
        // "blink": it vanished during the fast configure step, leaving the
        // network wait with no loader.
        SpinnerView.showFullScreen()
        await Task.yield()

        do {
            try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)
        } catch {
            SpinnerView.hideFullScreen()
            AlertManager.shared.showError("Unable to initialize. Please try again.")
            return
        }

        // Spinner lifecycle across the flow:
        //  • onPresented (Plaid `.open`)  → hide  (Plaid's own UI is now visible)
        //  • onLinking  (Plaid dismissed) → show  (cover the backend link call so
        //                                          the screen isn't blank)
        // startPlaidLink returns the linked account only after the backend link
        // completes; nil on cancel/failure.
        let linked = await plaidVM.startPlaidLink(
            onPresented: { SpinnerView.hideFullScreen() },
            onLinking: { SpinnerView.showFullScreen() }
        )

        // Backend done (or flow failed/cancelled) — drop the spinner before
        // presenting the success screen (the spinner window sits above it).
        SpinnerView.hideFullScreen()

        guard let linked else { return }

        onLinked(linked)
        // Setting the item presents the cover; the content receives this exact
        // account, so the FROM row is always populated.
        linkedAccount = linked
    }
}

// MARK: - View convenience

extension View {
    /// Attaches the Plaid link flow. Flip `isActive` to `true` (typically from the
    /// info sheet's `onDismiss`) to start it once the info screen is gone.
    func plaidLinkFlow(
        isActive: Binding<Bool>,
        plaidVM: PlaidAchViewModel,
        container: AppContainer,
        primaryAccount: SavingsAccountInfo? = nil,
        allowFunding: Bool,
        onLinked: @escaping (ACHAccount) -> Void = { _ in },
        onDone: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            PlaidLinkFlowModifier(
                plaidVM: plaidVM,
                isActive: isActive,
                container: container,
                primaryAccount: primaryAccount,
                allowFunding: allowFunding,
                onLinked: onLinked,
                onDone: onDone
            )
        )
    }
}
