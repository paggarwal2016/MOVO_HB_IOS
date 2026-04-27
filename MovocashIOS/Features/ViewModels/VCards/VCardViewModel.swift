//
//  VCardViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import Combine

@MainActor
final class VCardViewModel: BaseViewModel {
    
    private let network: NetworkServiceProtocol
    private let analytics: AnalyticsTracking

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        super.init(alertManager: alertManager)
    }

    // MARK: - Vcard get

    func getVCardPrimary() async throws -> VCardPrimaryResponse? {
        var result: VCardPrimaryResponse?
        try await perform {
            do {
                result = try await self.network.request(VCardAPI.getVCardsPrimary)
                self.analytics.log(AnalyticsEvent.vcardViewed)
            } catch NetworkError.noContent {
                // 204 — user has no primary card yet; treat as success with no data
            }
            // Any other error propagates to perform {}, which shows a toast
        }
        return result
    }

    // MARK: - Vcard All

    func getVCardsList() async throws -> [VCardsList] {
        do {
            let response: VCardsResponse = try await perform { try await self.network.request(VCardAPI.getVCardsList) }
            analytics.log(AnalyticsEvent.vcardViewed)
            return response.data ?? []
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    func getVCardsAll() async throws -> [VCardListResponse] {
        do {
            let response: VCardListAllResponse = try await perform { try await self.network.request(VCardAPI.getVCardsList) }
            analytics.log(AnalyticsEvent.vcardViewed)
            return response.data ?? []
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    // MARK: - Vcard post

    func postVCard(request: VCardsRequest) async throws -> VCardsList {
        do {
            let response: VCardsResponse = try await perform { try await self.network.request(VCardAPI.postVCards(request: request)) }
            guard let card = response.data?.first else { throw NetworkError.decodingError }
            analytics.log(AnalyticsEvent.vcardCreated, params: [
                AnalyticsParam.accountId: request.accountId
            ])
            return card
        } catch {
            analytics.log(AnalyticsEvent.vcardCreateFailed, params: [
                AnalyticsParam.accountId: request.accountId
            ])
            throw error
        }
    }
    
    /// Creates a virtual card.
    ///
    /// - Parameters:
    ///   - request:   Card creation payload.
    ///   - encrypted: Pass `true` (default) when the server returns an encrypted response
    ///                (`x-encrypt-response: true` header). Pass `false` for plain `VCardsResponse`.
    func createVCard(request: CreateVCardRequest, encrypted: Bool = true) async throws -> VCardsList {
        if encrypted {
            // Server returns: { "success": true, "data": { "encryptedData": "<base64>" } }
            let response: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.createVCard(request: request))
            }
            guard let encryptedBase64 = response.data?.encryptedData else {
                throw NetworkError.decodingError
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
            return try JSONDecoder().decode(VCardsList.self, from: plainData)
        } else {
            // Server returns: { "success": true, "data": [{ "cardNumber": ..., ... }] }
            let response: VCardsResponse = try await perform {
                try await self.network.request(VCardAPI.createVCard(request: request))
            }
            guard let card = response.data?.first else { throw NetworkError.decodingError }
            return card
        }
    }
}
