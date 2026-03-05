//
//  PlaidService.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
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
}

