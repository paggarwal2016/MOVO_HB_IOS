//
//  PlaidAchViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 07/04/26.
//

import Foundation
import Combine
import MobileBankingSDK
import UIKit

@MainActor
final class PlaidAchViewModel: ObservableObject, TokenRefreshable {

    private let service: PlaidService
    private let plaidLinkManager: PlaidLinkManagerProtocol
    let network: NetworkServiceProtocol
    let keychain: KeychainManagerProtocol
    private let analytics: AnalyticsTracking = AnalyticsManager.shared

    // MARK: - Published State

    @Published var state: ModelState = .idle

    // Auth
    @Published var authToken: OAuthToken?

    // ACH
    @Published var plaidLinkToken: GetPlaidLinkTokenResponse?
    @Published var linkedAccount: LinkPlaidAccountResponse?
    @Published var achPaymentMethods: GetAchPaymentMethodsResponse?

    // Transactions
    @Published var transactions: GetTransactionsResponse?
    @Published var withdrawResult: WithdrawFundsResponse?

    // Virtual Card
    @Published var virtualCard: VirtualCard?
    @Published var provisionData: AppleProvisionData?

    // Apple Wallet
    @Published var provisionedPass: AppleWalletProvisionedPass?
    @Published var canAddToWallet: Bool = false

    init(
        service: PlaidService = .shared,
        network: NetworkServiceProtocol? = nil,
        keychain: KeychainManagerProtocol? = nil,
        plaidLinkManager: PlaidLinkManagerProtocol? = nil
    ) {
        let resolvedNetwork = network ?? NetworkService.shared
        let resolvedKeychain = keychain ?? KeychainManager.shared
        self.service = service
        self.network = resolvedNetwork
        self.keychain = resolvedKeychain
        self.plaidLinkManager = plaidLinkManager ?? PlaidLinkManager(
            network: resolvedNetwork,
            keychain: resolvedKeychain
        )
    }

    // MARK: - Auth

    func sendOtp(request: SendOtpRequestBody) async throws -> SendOtpResponse {
        return try await run { try await self.service.sendOtp(request: request) }
    }

    func loginWithSms(request: AuthWithOtpRequestBody) async {
        await perform {
            self.authToken = try await self.service.loginWithSms(request: request)
        }
    }

    func loginWithPrivateKey(request: AuthWithRsaRequestBody) async {
        await perform {
            self.authToken = try await self.service.loginWithPrivateKey(request: request)
        }
    }

    func refreshToken(request: RefreshTokenRequestBody) async {
        await perform {
            self.authToken = try await self.service.refreshToken(request: request)
        }
    }

    func saveBiometricLoginKey(request: SaveBiometricLoginKeyRequestBody) async throws -> Bool {
        return try await run { try await self.service.saveBiometricLoginKey(request: request) }
    }

    // MARK: - ACH

    func fetchLinkToken(accountID: Int? = nil) async throws -> GetPlaidLinkTokenResponse {
        return try await run { [self] in
            let response = try await self.service.getLinkToken(accountID: accountID)
            self.plaidLinkToken = response
            return response
        }
    }

    func linkPlaidAccount(request: LinkPlaidAccountRequestBody) async {
        await perform {
            self.linkedAccount = try await self.service.linkPlaidAccount(request: request)
        }
    }

    func processAchDeposit(request: ProcessAchDepositRequestBody) async {
        await perform {
            try await self.service.processAchDeposit(request: request)
        }
    }

    func fetchAchPaymentMethods() async {
        await perform {
            self.achPaymentMethods = try await self.service.getAchPaymentMethods()
        }
    }

    func deleteAchAccount(achAccountId: Int) async {
        await perform {
            try await self.service.deleteAchAccount(achAccountId: achAccountId)
        }
    }

    func setDefaultAchAccount(achAccountId: Int) async {
        await perform {
            try await self.service.setDefaultAchAccount(achAccountId: achAccountId)
        }
    }

    // MARK: - Plaid Link Flow

    /// Full Plaid Link flow: fetch token → present Plaid UI → link account on backend.
    ///
    /// On success it fetches the full ACH account list (`getAccounts`) and returns
    /// the freshly linked `ACHAccount` — matched on `plaidAccountId` — so the caller
    /// can bind a fully-populated account (real balance + achAccountId) into its
    /// local store. If that fetch fails or no match is found, it falls back to a
    /// display-only account built from the Plaid metadata (balance/achAccountId 0).
    /// Returns nil if the user cancelled or any step failed (errors surfaced via
    /// AlertManager).
    /// - Parameters:
    ///   - onPresented: fires when Plaid's UI appears (hide any loading spinner).
    ///   - onLinking: fires after Plaid succeeds, just before the backend link
    ///     call (re-show a loader to cover that network round-trip).
    @discardableResult
    func startPlaidLink(
        accountID: Int? = nil,
        onPresented: (() -> Void)? = nil,
        onLinking: (() -> Void)? = nil
    ) async -> ACHAccount? {
        async let presenterTask = waitForPresentableViewController()

        let tokenResponse: GetPlaidLinkTokenResponse
        do {
            tokenResponse = try await fetchLinkToken(accountID: accountID)
        } catch {
            _ = await presenterTask
            SecureLogger.error("[Plaid] link token fetch failed — \(error.localizedDescription)", category: .payment)
            return nil
        }

        guard !tokenResponse.linkToken.isEmpty else {
            _ = await presenterTask
            SecureLogger.error("[Plaid] backend returned an empty link token", category: .payment)
            AlertManager.shared.showError("Unable to start bank linking. Please try again.")
            return nil
        }

        guard let presenter = await presenterTask else {
            // Device/app-level: nothing available to present Plaid from.
            SecureLogger.error("[Plaid] no presentable view controller", category: .payment)
            AlertManager.shared.showError(PlaidLinkError.noPresenter.localizedDescription)
            return nil
        }

        let plaidResult: PlaidLinkResult
        do {
            plaidResult = try await plaidLinkManager.openLink(
                token: tokenResponse.linkToken,
                presenter: presenter,
                onPresented: onPresented
            )
        } catch {
            if case PlaidLinkError.linkExited(nil) = error {
                SecureLogger.info("[Plaid] Link closed by user", category: .payment)
                return nil
            }
            SecureLogger.error("[Plaid] openLink failed — \(error.localizedDescription)", category: .payment)
            AlertManager.shared.showError(error.localizedDescription)
            return nil
        }

        // Plaid succeeded and is dismissing — surface a loader for the backend
        // link round-trip so the screen isn't blank until the success screen.
        onLinking?()

        let request = LinkPlaidAccountRequestBody(
            public_token: plaidResult.publicToken,
            metadata: plaidResult.metadata,
            shouldGetIdentity: nil
        )

        do {
            // `run` surfaces the error alert and rethrows on failure.
            SecureLogger.info("[Plaid] linking account on backend (POST /ach/plaid/link)", category: .payment)
            let response = try await run { try await self.service.linkPlaidAccount(request: request) }
            self.linkedAccount = response

            SecureLogger.info("[Plaid] backend link succeeded — status=\(response.status) accountsAdded=\(response.accountsAdded.count)", category: .payment)

            // Sync the linked accounts to the Movo middleware (POST /ach/plaid/accounts).
            let accountsRequest = PlaidAccountRequest(
                status: response.status,
                accountsAdded: response.accountsAdded.map {
                    PlaidAccount(
                        plaidAccountId: $0.plaidAccountId,
                        resourceId: $0.resourceId,
                        savingsId: $0.savingsId,
                        customerId: $0.clientId,
                        officeId: $0.officeId
                    )
                },
                userAction: "LINK-PLAID-ACCOUNT-SAVED"
            )
            do {
                let syncData = try await self.network.requestData(AchAPI.achPlaidAccount(request: accountsRequest))
                let syncBody = String(data: syncData, encoding: .utf8) ?? "<\(syncData.count) bytes>"
                SecureLogger.info("[Plaid] middleware sync response (POST /ach/plaid/accounts): \(syncBody)", category: .payment)
            } catch {
                SecureLogger.error("[Plaid] middleware sync failed — \(error.localizedDescription)", category: .payment)
            }

            return Self.makeLinkedAccount(
                from: plaidResult.metadata,
                savingsId: response.accountsAdded.first?.resourceId ?? 0
            )
        } catch {
            SecureLogger.error("[Plaid] backend link failed — \(error.localizedDescription)", category: .payment)
            return nil
        }
    }

    /// Builds a display `ACHAccount` from the Plaid link metadata. The balance is
    /// unknown at link time (0); `achAccountId` is set from the link response's
    /// `savingsId` (the link response carries no separate ACH account id).
    private static func makeLinkedAccount(from metadata: LinkPlaidLinkMetadata, savingsId: Int) -> ACHAccount {
        let account = metadata.accounts.first
        return ACHAccount(
            plaidAccountId: account?.id ?? "",
            plaidAccountBalance: 0,
            isPlaidLoginRequired: false,
            isDefault: false,
            institutionLogo: "",
            accountNumber: account?.mask ?? "",
            accountName: account?.name ?? "Checking",
            institutionName: metadata.institution.name,
            achAccountId: savingsId
        )
    }

    // MARK: - Transactions

    func fetchTransactions(max: Int? = nil) async {
        await perform {
            self.transactions = try await self.service.getTransactions(max: max)
        }
    }

    func withdrawFunds(request: WithdrawFundsRequestBody) async {
        await perform {
            self.withdrawResult = try await self.service.withdrawFunds(request: request)
        }
    }

    // MARK: - Virtual Card

    func fetchVirtualCard() async {
        await perform {
            self.virtualCard = try await self.service.getVirtualCard()
        }
    }

    func activateCard(pin: String, accountId: Int? = nil) async {
        await perform {
            do {
                self.virtualCard = try await self.service.activateVirtualCard(pin: pin, accountId: accountId)
                self.analytics.log(AnalyticsEvent.cardActivated)
            } catch {
                self.analytics.log(AnalyticsEvent.cardActivationFailed, params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription])
                throw error
            }
        }
    }

    func provisionVirtualCardForMobile(request: ProvisioningRequestBody) async {
        await perform {
            self.provisionData = try await self.service.provisionVirtualCardForMobile(request: request)
        }
    }

    /// Reveals the virtual card CVV after a passkey step-up prompt.

    func revealVirtualCardCvv(accountId: Int, enableEncryptedResponses: Bool = false) async throws -> String {
        return try await run {
            guard let token = try? await self.keychain.get("access_token", biometricPrompt: nil),
                  !token.isEmpty,
                  let json = JWTDecoder.decodePayload(token),
                  let payload = json["payload"] as? [String: Any],
                  let userIdInt = payload["userId"] as? Int
            else {
                throw NSError(domain: "VirtualCard", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to verify device identity. Please try again."])
            }
            try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)

            let passkeyKey = "passkey_registered_\(userIdInt)"
            if case .found = self.keychain.getSync(passkeyKey) {
                // Already registered — proceed.
            } else {
                guard let reRegPresenter = await self.waitForPresentableViewController() else {
                    throw NSError(domain: "VirtualCard", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
                do {
                    try await self.service.registerDevicePasskey(presentingViewController: reRegPresenter)
                    try? await self.keychain.save("1", for: passkeyKey, protection: .backgroundSafe)
                    SecureLogger.info("Device passkey registered for user \(userIdInt) during CVV reveal", category: .auth)
                } catch {
                    SecureLogger.error("Passkey registration failed: \(error.localizedDescription)", category: .auth)
                    throw NSError(domain: "VirtualCard", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
            }

            guard let presenter = await self.waitForPresentableViewController() else {
                throw NSError(domain: "VirtualCard", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to present CVV verification."])
            }
            let response = try await self.service.getVirtualCardCvvSecure(
                accountId: accountId,
                presentingViewController: presenter,
                enableEncryptedResponses: enableEncryptedResponses
            )
            return response.cvv
        }
    }

    // MARK: - Apple Wallet

    var canProvisionAppleWalletPasses: Bool {
        MobileBankingSDK.canProvisionAppleWalletPasses
    }

    @discardableResult
    func checkCanAddToWallet(
        primaryAccountNumberSuffix: String,
        localizedDescription: String? = nil
    ) -> Bool {
        let result = service.canAddVirtualCardToAppleWallet(
            primaryAccountNumberSuffix: primaryAccountNumberSuffix,
            localizedDescription: localizedDescription
        )
        canAddToWallet = result
        return result
    }

    @discardableResult
    func viewVirtualCardInAppleWallet(
        primaryAccountNumberSuffix: String,
        localizedDescription: String? = nil
    ) -> Bool {
        return service.viewVirtualCardInAppleWallet(
            primaryAccountNumberSuffix: primaryAccountNumberSuffix,
            localizedDescription: localizedDescription
        )
    }

    func addVirtualCardToAppleWallet(accountId: Int? = nil, localizedDescription: String? = nil) async {
        guard let presenter = await waitForPresentableViewController() else {
            SecureLogger.error("[Wallet] no presentable view controller for add-to-wallet", category: .payment)
            AlertManager.shared.showError("Unable to present wallet flow.")
            return
        }
        await perform {
            do {
                self.provisionedPass = try await self.service.addVirtualCardToAppleWallet(
                    presentingViewController: presenter,
                    accountId: accountId,
                    localizedDescription: localizedDescription
                )
                self.analytics.log(AnalyticsEvent.walletAdd)
                SecureLogger.info("[Wallet] virtual card added to Apple Wallet", category: .payment)
            } catch {
                self.analytics.log(
                    AnalyticsEvent.walletAddFailed,
                    params: [AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription]
                )
                SecureLogger.error("[Wallet] add-to-wallet did not complete: \(error.localizedDescription)", category: .payment)
            }
        }
    }

    func activateVirtualCard(pin: String, accountId: Int? = nil, localizedDescription: String? = nil) async {
        guard let presenter = await waitForPresentableViewController() else {
            AlertManager.shared.showError("Unable to present wallet flow.")
            return
        }
        await perform {
            self.provisionedPass = try await self.service.activateVirtualCardAndAddToAppleWallet(
                pin: pin,
                presentingViewController: presenter,
                accountId: accountId,
                localizedDescription: localizedDescription
            )
        }
    }

    // MARK: -   Intent

    @Published var transactionIntent: TransactionIntent?
    @Published var peerTransferSuccess: SuccessConfirmation?

    func configureSDKForTransfer() async {
        guard let token = try? await keychain.get("access_token", biometricPrompt: nil),
              !token.isEmpty else { return }
        await service.configureSDKForTransfer(authToken: token)
    }

    func createTransactionIntent(requestBody: CreateTransactionIntentRequestBody) async throws -> TransactionIntent {
        try await run {
            let intent = try await self.service.createTransactionIntent(requestBody: requestBody)
            self.transactionIntent = intent
            return intent
        }
    }

    @discardableResult
    func approveTransactionIntent(intentId: String) async throws -> SecureTransactionApprovalResult {
        guard let presenter = await waitForPresentableViewController() else {
            throw NSError(domain: "QuickTransfer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to present biometric approval."])
        }
        let deviceId = await DeviceManager.shared.deviceID()
        return try await run {
            try await self.service.approveTransactionIntent(
                intentId: intentId,
                deviceId: deviceId,
                presentingViewController: presenter
            )
        }
    }

    func sendMoneyToContact(
        fromCard: VCardListResponse,
        toName: String,
        normalizedPhone: String,
        amount: Double,
        amountText: String,
        description: String?,
        isInternal: Bool = false,
        toClientId: Int? = nil,
        toAccountId: Int? = nil,
        toMask: String? = nil
    ) async {
        await perform {
            try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)

            guard let passkeyToken = try? await self.keychain.get("access_token", biometricPrompt: nil),
                  let json = JWTDecoder.decodePayload(passkeyToken),
                  let payload = json["payload"] as? [String: Any],
                  let userIdInt = payload["userId"] as? Int
            else {
                throw NSError(domain: "QuickTransfer", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to verify device identity. Please try again."])
            }
            let passkeyKey = "passkey_registered_\(userIdInt)"
            if case .found = self.keychain.getSync(passkeyKey) {
                // Already registered — proceed.
            } else {
                guard let reRegPresenter = await self.waitForPresentableViewController() else {
                    throw NSError(domain: "QuickTransfer", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
                do {
                    try await self.service.registerDevicePasskey(presentingViewController: reRegPresenter)
                    try? await self.keychain.save("1", for: passkeyKey, protection: .backgroundSafe)
                    SecureLogger.info("Device passkey re-registered for user \(userIdInt) during transfer", category: .auth)
                } catch {
                    SecureLogger.error("Passkey re-registration failed: \(error.localizedDescription)", category: .auth)
                    throw NSError(domain: "QuickTransfer", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
            }

            let requestBody = CreateTransactionIntentRequestBody(
                type:    isInternal ? .internalTransfer : .externalTransfer,
                details: isInternal
                    ? .internalTransfer(
                        amount: amount,
                        fromAccountId: fromCard.savingsAccountId,
                        phoneNumber: normalizedPhone.isEmpty ? nil : normalizedPhone,
                        toClientId: toClientId,
                        toAccountId: toAccountId,
                        description: description
                    )
                    : .externalTransfer(
                        fromAccountId: fromCard.savingsAccountId ?? 0,
                        recipientPhoneNumber: normalizedPhone,
                        amount: amount,
                        description: description
                    ),
                webhookUrl: nil
            )
            let intent = try await self.service.createTransactionIntent(requestBody: requestBody)
            self.transactionIntent = intent

            guard let approvalPresenter = await self.waitForPresentableViewController() else {
                throw NSError(domain: "QuickTransfer", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to present biometric approval."])
            }
            let deviceId = await DeviceManager.shared.deviceID()
            self.state = .idle
            let approvalResult = try await self.service.approveTransactionIntent(
                intentId: intent.id,
                deviceId: deviceId,
                presentingViewController: approvalPresenter,
                approvalSheetHeight: .fraction(0.85)
            )
            self.state = .loading

            let completeRequest = TransactionRequest.Complete(
                transferId:    approvalResult.intent.id,
                amount:        amountText,
                fromAccountId: fromCard.savingsAccountId ?? 0,
                toAccountId:   toAccountId ?? 0,
                toClientId:    toClientId ?? 0,
                phoneNumber:   normalizedPhone,
                nickname:      toName,
                userType: isInternal ? "internal" : "external"
            )
            do {
                let data = try await self.network.requestData(TransactionAPI.complete(completeRequest))
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                SecureLogger.debug("intent-complete response: \(body)", category: .payment)
            } catch {
                SecureLogger.error("intent-complete failed: \(error.localizedDescription)", category: .payment)
            }

            self.peerTransferSuccess = SuccessConfirmation(
                channel: .peer,
                amount: Decimal(string: amountText) ?? 0,
                fromAccountName: fromCard.savingsAccountNickname ?? fromCard.name ?? fromCard.displayName,
                fromAccountMask: fromCard.maskedNumber,
                toAccountName: toName,
                toAccountMask: toMask ?? normalizedPhone,
                arrivesText: "Instantly",
                dateText: Date.now.formatted(date: .long, time: .shortened),
                referenceCode: approvalResult.intent.id
            )
        }
    }
    
    // MARK: - Helpers

    // Polls until the top VC is fully settled with no active child presentation (max 2s).
    // We intentionally wait out an in-progress dismissal (`isBeingDismissed`) rather than
    // returning that VC: presenting the SDK's approval sheet while a dismissal is still
    // running makes UIKit refuse to present, and the SDK then never calls its completion —
    // which leaks the approval continuation and hangs the transfer forever.
    private func waitForPresentableViewController() async -> UIViewController? {
        for _ in 0..<20 {
            if let vc = UIApplication.topViewController(),
               vc.presentedViewController == nil {
                return vc
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return UIApplication.topViewController()
    }

    // Wraps a throwing async call — manages state and surfaces errors.
    private func perform(_ block: @escaping () async throws -> Void) async {
        guard state != .loading else { return }
        state = .loading
        defer { state = .idle }
        do {
            try await block()
            state = .success
        } catch {
            state = .failure
        }
    }

    // Same as perform but returns a value and rethrows for callers that need the result.
    private func run<T>(_ block: @escaping () async throws -> T) async throws -> T {
        guard state != .loading else {
            throw NSError(domain: "Already loading", code: 1)
        }
        state = .loading
        defer { state = .idle }
        do {
            let result = try await block()
            state = .success
            return result
        } catch {
            state = .failure
            AlertManager.shared.showError(error.localizedDescription)
            throw error
        }
    }
}

// MARK: - ModelState

enum ModelState: Equatable {
    case idle
    case loading
    case success
    case failure
}
