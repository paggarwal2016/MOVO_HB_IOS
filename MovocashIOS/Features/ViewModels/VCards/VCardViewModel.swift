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

    func getVCardPrimary() async throws -> VCardsResponse? {
        var result: VCardsResponse?
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
    
    func createVCard(request: CreateVCardRequest) async throws -> VCardsList {
        do {
            let response: VCardsResponse = try await perform { try await self.network.request(VCardAPI.createVCard(request: request)) }
            guard let card = response.data?.first else { throw NetworkError.decodingError }
//            analytics.log(AnalyticsEvent.vcardCreated, params: [
//                AnalyticsParam.accountId: request.accountId
//            ])
            return card
        } catch {
//            analytics.log(AnalyticsEvent.vcardCreateFailed, params: [
//                AnalyticsParam.accountId: request.accountId
//            ])
            throw error
        }
    }
}
