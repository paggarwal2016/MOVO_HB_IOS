//
//  PlaidService.swift
//  MovocashIOS
//
//  Created by Vinu on 03/03/26.
//

import Foundation
import MobileBankingSDK
import UIKit

actor PlaidService {

    static let shared = PlaidService()

    private init() { }

    // MARK: - Auth

    func sendOtp(request: SendOtpRequestBody) async throws -> SendOtpResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.sendOtp(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func loginWithSms(request: AuthWithOtpRequestBody) async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.loginWithSms(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func loginWithPrivateKey(request: AuthWithRsaRequestBody) async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.loginWithPrivateKey(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func refreshToken(request: RefreshTokenRequestBody) async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.refreshToken(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func saveBiometricLoginKey(request: SaveBiometricLoginKeyRequestBody) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.saveBiometricLoginKey(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - ACH

    func getLinkToken(accountID: Int? = nil) async throws -> GetPlaidLinkTokenResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.getPlaidLinkToken(
                accountId: accountID,
                platform: "ios",
                bundleId: AppInfo.bundleIdentifier
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    func linkPlaidAccount(request: LinkPlaidAccountRequestBody) async throws -> LinkPlaidAccountResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.linkPlaidAccount(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func processAchDeposit(request: ProcessAchDepositRequestBody) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.processAchDeposit(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func getAchPaymentMethods() async throws -> GetAchPaymentMethodsResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.getAchPaymentMethods { result in
                continuation.resume(with: result)
            }
        }
    }

    func deleteAchAccount(achAccountId: Int) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.deleteAchAccount(achAccountId: achAccountId) { result in
                continuation.resume(with: result)
            }
        }
    }

    func setDefaultAchAccount(achAccountId: Int) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.setDefaultAchAccount(achAccountId: achAccountId) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Transactions

    func getTransactions(max: Int? = nil) async throws -> GetTransactionsResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.getTransactions(max: max) { result in
                continuation.resume(with: result)
            }
        }
    }

    func withdrawFunds(request: WithdrawFundsRequestBody) async throws -> WithdrawFundsResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.withdrawFunds(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Virtual Card

    func getVirtualCard() async throws -> VirtualCard? {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.getVirtualCard { result in
                continuation.resume(with: result)
            }
        }
    }

    func activateVirtualCard(pin: String, accountId: Int? = nil) async throws -> VirtualCard? {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.activateVirtualCard(
                requestBody: ActivateVirtualCardRequestBody(pin: pin, accountId: accountId)
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    func provisionVirtualCardForMobile(request: ProvisioningRequestBody) async throws -> AppleProvisionData {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.provisionVirtualCardForMobile(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Apple Wallet

    nonisolated var canProvisionAppleWalletPasses: Bool {
        MobileBankingSDK.canProvisionAppleWalletPasses
    }

    nonisolated func canAddVirtualCardToAppleWallet(
        primaryAccountNumberSuffix: String,
        localizedDescription: String? = nil
    ) -> Bool {
        return MobileBankingSDK.canAddVirtualCardToAppleWallet(
            primaryAccountNumberSuffix: primaryAccountNumberSuffix,
            localizedDescription: localizedDescription
        )
    }

    @discardableResult
    nonisolated func viewVirtualCardInAppleWallet(
        primaryAccountNumberSuffix: String,
        localizedDescription: String? = nil
    ) -> Bool {
        return MobileBankingSDK.viewVirtualCardInAppleWallet(
            primaryAccountNumberSuffix: primaryAccountNumberSuffix,
            localizedDescription: localizedDescription
        )
    }

    @MainActor
    func addVirtualCardToAppleWallet(
        presentingViewController: UIViewController,
        accountId: Int? = nil,
        localizedDescription: String? = nil
    ) async throws -> AppleWalletProvisionedPass {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.addVirtualCardToAppleWallet(
                presentingViewController: presentingViewController,
                accountId: accountId,
                localizedDescription: localizedDescription
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    @MainActor
    func activateVirtualCardAndAddToAppleWallet(
        pin: String,
        presentingViewController: UIViewController,
        accountId: Int? = nil,
        localizedDescription: String? = nil
    ) async throws -> AppleWalletProvisionedPass {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.activateVirtualCardAndAddToAppleWallet(
                pin: pin,
                presentingViewController: presentingViewController,
                accountId: accountId,
                localizedDescription: localizedDescription
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
}
