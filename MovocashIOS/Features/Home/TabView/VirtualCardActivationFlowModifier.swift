//
//  VirtualCardActivationFlowModifier.swift
//  MovocashIOS
//

import SwiftUI

// MARK: - VirtualCardActivationFlowModifier

private struct ActivateCardAccount: Identifiable {
    let id: Int
}

private struct PendingActivation {
    let pin: String
    let accountId: Int
}

struct VirtualCardActivationFlowModifier: ViewModifier {
    
    let vCardVM: VCardViewModel
    @ObservedObject var plaidVM: PlaidAchViewModel
    @Binding var isActive: Bool
    var accountId: Int?
    var title: String = "Set your Main MOVO card PIN"
    var onAllSet: () -> Void = {}
    var onRequiresSupport: () -> Void = {}
    var allSetContent: (AnyView) -> AnyView = { $0 }
    /// Primary account →  Activation  →  PIN entry →  SDK activation  →  Apple Wallet result
    @State private var activateCardAccount: ActivateCardAccount?
    @State private var pendingActivation: PendingActivation?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { active in
                guard active else { return }
                // Consume the trigger immediately so it fires exactly once.
                isActive = false
                // `id == 0` is never a real account id — treat it the same as
                // "not found yet" rather than sending a bogus accountId through.
                guard let accountId, accountId != 0 else {
                    AlertManager.shared.showError("Unable to find your account. Please try again.")
                    return
                }
                // Primary account →  Activation
                activateCardAccount = ActivateCardAccount(id: accountId)
            }
        // Activation →  PIN entry
            .fullScreenCover(item: $activateCardAccount, onDismiss: {
                launchPendingActivationIfNeeded()
            }) { account in
                CreateCashCardView(
                    vm: vCardVM,
                    plaidVM: plaidVM,
                    primaryAccountId: account.id,
                    title: title,
                    mode: .activate,
                    nicknameFieldLabel: "NICK NAME",
                    fixedNickname: "MOVO Vault Card",
                    isNicknameEditable: false,
                    onClose: { activateCardAccount = nil },
                    onPinConfirmed: { pin in
                        pendingActivation = PendingActivation(pin: pin, accountId: account.id)
                        activateCardAccount = nil
                    }
                )
            }
        // SDK activation →  Apple Wallet result
            .fullScreenCover(isPresented: $plaidVM.showVirtualCardAllSet) {
                allSetContent(
                    AnyView(
                        VirtualCardAllSetView(
                            title: "Your Main MOVO card is ready to use!",
                            message: allSetMessage,
                            onDone: onAllSet
                        )
                    )
                )
            }
    }
    
    // PIN entry →  SDK activation
    private func launchPendingActivationIfNeeded() {
        guard let pending = pendingActivation else { return }
        pendingActivation = nil
        Task {
            await plaidVM.activateVirtualCard(
                pin: pending.pin,
                accountId: pending.accountId,
                onRequiresSupport: onRequiresSupport
            )
        }
    }
    
    private var allSetMessage: String {
        switch plaidVM.walletProvisioningOutcome {
        case .activeButNotInWallet:
            return "We couldn\u{2019}t add it to Apple Wallet right now \u{2014} you can try again anytime from your Card screen."
        case .addedToWallet, .none:
            return "Your Main MOVO card has been added to Apple Wallet. Add money to start spending."
        }
    }
}

// MARK: - View convenience

extension View {
    /// Attaches the virtual-card activation flow. Flip `isActive` to `true` once
    /// the primary account id is known to start PIN entry.
    func virtualCardActivationFlow(
        vCardVM: VCardViewModel,
        plaidVM: PlaidAchViewModel,
        isActive: Binding<Bool>,
        accountId: Int?,
        title: String = "Set your Main MOVO card PIN",
        onAllSet: @escaping () -> Void = {},
        onRequiresSupport: @escaping () -> Void = {},
        allSetContent: @escaping (AnyView) -> AnyView = { $0 }
    ) -> some View {
        modifier(
            VirtualCardActivationFlowModifier(
                vCardVM: vCardVM,
                plaidVM: plaidVM,
                isActive: isActive,
                accountId: accountId,
                title: title,
                onAllSet: onAllSet,
                onRequiresSupport: onRequiresSupport,
                allSetContent: allSetContent
            )
        )
    }
}
