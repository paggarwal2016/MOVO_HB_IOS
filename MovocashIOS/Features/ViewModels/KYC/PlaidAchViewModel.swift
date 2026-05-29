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
    func startPlaidLink(accountID: Int? = nil) async {
        let tokenResponse: GetPlaidLinkTokenResponse
        do {
            tokenResponse = try await fetchLinkToken(accountID: accountID)
        } catch {
            return
        }

        guard !tokenResponse.linkToken.isEmpty else {
            AlertManager.shared.showError("Unable to start bank linking. Please try again.")
            return
        }

        guard let presenter = await waitForPresentableViewController() else {
            AlertManager.shared.showError(PlaidLinkError.noPresenter.localizedDescription)
            return
        }

        let plaidResult: PlaidLinkResult
        do {
            plaidResult = try await plaidLinkManager.openLink(
                token: tokenResponse.linkToken,
                presenter: presenter
            )
        } catch {
            if case PlaidLinkError.linkExited(nil) = error {
                SecureLogger.info("Plaid Link closed by user", category: .payment)
                return
            }
            AlertManager.shared.showError(error.localizedDescription)
            return
        }

        let request = LinkPlaidAccountRequestBody(
            public_token: plaidResult.publicToken,
            metadata: plaidResult.metadata,
            shouldGetIdentity: nil
        )

        await linkPlaidAccount(request: request)
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
            self.virtualCard = try await self.service.activateVirtualCard(pin: pin, accountId: accountId)
        }
    }

    func provisionVirtualCardForMobile(request: ProvisioningRequestBody) async {
        await perform {
            self.provisionData = try await self.service.provisionVirtualCardForMobile(request: request)
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
            AlertManager.shared.showError("Unable to present wallet flow.")
            return
        }
        await perform {
            self.provisionedPass = try await self.service.addVirtualCardToAppleWallet(
                presentingViewController: presenter,
                accountId: accountId,
                localizedDescription: localizedDescription
            )
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

    // MARK: - Transaction Intent

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
        isInternal: Bool = false
    ) async {
        await perform {
            // Step 1 — Configure KYC SDK on every transfer so the SDK always holds
            // the current token. Skipping this with an isConfigured guard would leave
            // the SDK using a stale/expired token after the first refresh cycle.
            try await KYCManager.shared.configureSDK(officeId: AppConfig.officeId)

            // Step 2 — Ensure device passkey is registered before attempting transfer.
            // Keychain is the source of truth (survives OS memory pressure; UserDefaults does not).
            // If the flag is missing (e.g. cleared by OS), attempt silent re-registration here
            // so the user never sees a "sign out" error for a transient OS eviction.
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
                // Flag missing: attempt silent re-registration before blocking the transfer.
                await self.service.configureSDKForTransfer(authToken: passkeyToken)
                let reRegDeviceId = await DeviceManager.shared.deviceID()
                guard let reRegPresenter = await self.waitForPresentableViewController() else {
                    throw NSError(domain: "QuickTransfer", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
                do {
                    try await self.service.registerDevicePasskey(
                        userId: String(userIdInt),
                        deviceId: reRegDeviceId,
                        presentingViewController: reRegPresenter
                    )
                    try? await self.keychain.save("1", for: passkeyKey, protection: .backgroundSafe)
                    SecureLogger.info("Device passkey re-registered for user \(userIdInt) during transfer", category: .auth)
                } catch {
                    SecureLogger.error("Passkey re-registration failed: \(error.localizedDescription)", category: .auth)
                    throw NSError(domain: "QuickTransfer", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Device registration failed. Please try again."])
                }
            }

            // Step 3 — Create transaction intent
            // Use .internalTransfer when the recipient is a registered MOVO user
            // (checkIntent returned exists == true), otherwise .externalTransfer.
            let requestBody = CreateTransactionIntentRequestBody(
                type:    isInternal ? .internalTransfer : .externalTransfer,
                details: isInternal
                    ? .internalTransfer(
                        amount: amount,
                        fromAccountId: fromCard.savingsAccountId ?? 0,
                        phoneNumber: normalizedPhone,
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

            // Step 4 — Approve intent (triggers biometric)
            guard let approvalPresenter = await self.waitForPresentableViewController() else {
                throw NSError(domain: "QuickTransfer", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to present biometric approval."])
            }
            let deviceId = await DeviceManager.shared.deviceID()
            let approvalResult = try await self.service.approveTransactionIntent(
                intentId: intent.id,
                deviceId: deviceId,
                presentingViewController: approvalPresenter
            )

            let completeRequest = TransactionRequest.Complete(
                transferId:    approvalResult.intent.id,
                amount:        amountText,
                fromAccountId: fromCard.savingsAccountId ?? 0,
                toAccountId:   0,
                toClientId:    0,
                phoneNumber:   normalizedPhone,
                nickname:      toName
            )
            // Best-effort: capture and log the response so failures are visible,
            // but never rethrow — a failure here must not break the approved transfer.
            do {
                let data = try await self.network.requestData(TransactionAPI.complete(completeRequest))
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                SecureLogger.debug("intent-complete response: \(body)", category: .payment)
            } catch {
                SecureLogger.error("intent-complete failed: \(error.localizedDescription)", category: .payment)
            }

            // Step 6 — Publish success
            self.peerTransferSuccess = SuccessConfirmation(
                channel: .peer,
                amount: Decimal(string: amountText) ?? 0,
                fromAccountName: fromCard.savingsAccountNickname ?? fromCard.name ?? fromCard.displayName,
                fromAccountMask: fromCard.maskedNumber,
                toAccountName: toName,
                toAccountMask: normalizedPhone,
                arrivesText: "Instantly",
                dateText: Date.now.formatted(date: .long, time: .shortened),
                referenceCode: approvalResult.intent.id
            )
        }
    }
    
    // MARK: - Helpers

    // Polls until the top VC has no active child presentation (max 2s).
    private func waitForPresentableViewController() async -> UIViewController? {
        for _ in 0..<20 {
            if let vc = UIApplication.topViewController(),
               vc.presentedViewController == nil || vc.presentedViewController?.isBeingDismissed == true {
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
            AlertManager.shared.showError(error.localizedDescription)
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
