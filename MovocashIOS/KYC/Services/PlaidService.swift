//
//  PlaidService.swift
//  MovocashIOS
//
//  Created by Vinu on 03/03/26.
//

import Foundation
import MobileBankingSDK

actor PlaidService {
    
    static let shared = PlaidService()
    
    private init() { }
    
    // GET - ACH - Plaid - Link
    func getLinkToken(accountID: Int? = nil) async throws -> GetPlaidLinkTokenResponse {
        let bundleId = await AppInfo.bundleIdentifier
        let platform = await AppInfo.platform
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.getPlaidLinkToken(
                accountId: accountID,
                platform: platform,
                bundleId: bundleId
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // POST - ACH - Plaid - Link
    func linkPlaidAccount(request: LinkPlaidAccountRequestBody) async throws -> LinkPlaidAccountResponse {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.linkPlaidAccount(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // POST - ACH
    func processAchDeposit(request: ProcessAchDepositRequestBody) async throws  {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.processAchDeposit(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // POST - Auth - refreshToken
    func refreshToken(request: RefreshTokenRequestBody) async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            MobileBankingSDK.refreshToken(requestBody: request) { result in
                continuation.resume(with: result)
            }
        }        
    }
    
    
    
    
    
    
    
    
//    public static func refreshToken(
//        requestBody: RefreshTokenRequestBody,
//        completion: @escaping (Result<OAuthToken, Error>) -> Void
//    ) {
//        refreshTokenRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func loginWithPrivateKey(
//        requestBody: AuthWithRsaRequestBody,
//        completion: @escaping (Result<OAuthToken, Error>) -> Void
//    ) {
//        loginWithPrivateKeyRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func loginWithSms(
//        requestBody: AuthWithOtpRequestBody,
//        completion: @escaping (Result<OAuthToken, Error>) -> Void
//    ) {
//        loginWithSmsRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func sendOtp(
//        requestBody: SendOtpRequestBody,
//        completion: @escaping (Result<SendOtpResponse, Error>) -> Void
//    ) {
//        sendOtpRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func saveBiometricLoginKey(
//        requestBody: SaveBiometricLoginKeyRequestBody,
//        completion: @escaping (Result<Bool, Error>) -> Void
//    ) {
//        saveBiometricLoginKeyRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func getTransactions(
//        max: Int? = nil,
//        completion: @escaping (Result<GetTransactionsResponse, Error>) -> Void
//    ) {
//        getTransactionsRequest(max: max, completion: completion)
//    }
//
//    public static func withdrawFunds(
//        requestBody: WithdrawFundsRequestBody,
//        completion: @escaping (Result<WithdrawFundsResponse, Error>) -> Void
//    ) {
//        withdrawFundsRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func getVirtualCard(
//        completion: @escaping (Result<VirtualCard?, Error>) -> Void
//    ) {
//        getVirtualCardRequest(completion: completion)
//    }
//
//    public static func activateVirtualCard(
//        requestBody: ActivateVirtualCardRequestBody,
//        completion: @escaping (Result<VirtualCard?, Error>) -> Void
//    ) {
//        activateVirtualCardRequest(requestBody: requestBody, completion: completion)
//    }
//
//    public static func provisionVirtualCardForMobile(
//        requestBody: ProvisioningRequestBody,
//        completion: @escaping (Result<VirtualCardProvisioningResponse, Error>) -> Void
//    ) {
//        provisionVirtualCardForMobileRequest(requestBody: requestBody, completion: completion)
//    }
    
}










//import SwiftUI
//
//@MainActor
//final class PlaidViewModel: ObservableObject {
//    
//    private let plaidService = PlaidService() // Use concrete class directly
//    
//    @Published var linkToken: PlaidLinkToken?
//    @Published var linkedAccount: PlaidLinkedAccount?
//    @Published var errorMessage: String?
//    
//    func fetchLinkToken(accountID: Int?) async {
//        do {
//            let token = try await plaidService.getLinkToken(accountID: accountID)
//            self.linkToken = token
//            print("Got Plaid token:", token.token)
//        } catch {
//            errorMessage = error.localizedDescription
//            print("Error fetching Plaid token:", error)
//        }
//    }
//    
//    func linkAccount(accountID: Int, linkToken: String) async {
//        do {
//            let requestBody = LinkPlaidAccountRequestBody(accountId: accountID, linkToken: linkToken)
//            let account = try await plaidService.linkPlaidAccount(requestBody: requestBody)
//            self.linkedAccount = account
//            print("Linked account successfully:", account)
//        } catch {
//            errorMessage = error.localizedDescription
//            print("Error linking account:", error)
//        }
//    }
//}
