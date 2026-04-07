//
//  ACHViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 03/03/26.
//

import Foundation
import Combine
import MobileBankingSDK
import UIKit

@MainActor
final class ACHViewModel: ObservableObject {

    private let service: PlaidService
    private let plaidLinkManager = PlaidLinkManager()

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

    init(service: PlaidService = .shared) {
        self.service = service
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
