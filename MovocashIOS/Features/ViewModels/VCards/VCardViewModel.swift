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

    func getVCardPrimary() async throws -> VCardsResponse {
        do {
            let response: VCardsResponse = try await perform { try await self.network.request(VCardAPI.getVCardsPrimary) }
            analytics.log(AnalyticsEvent.vcardViewed)
            return response
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }
    
    // MARK: - Vcard All

    func getVCardsList() async throws -> [VCardListResponse] {
        do {
            let response: [VCardListResponse] = try await perform { try await self.network.request(VCardAPI.getVCardsList) }
            analytics.log(AnalyticsEvent.vcardViewed)
            return response
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    // MARK: - Vcard post

    func postVCard(request: VCardsRequest) async throws -> VCardsResponse {
        do {
            let response: VCardsResponse = try await perform { try await self.network.request(VCardAPI.postVCards(request: request)) }
            analytics.log(AnalyticsEvent.vcardCreated, params: [
                AnalyticsParam.accountId: request.accountId
            ])
            return response
        } catch {
            analytics.log(AnalyticsEvent.vcardCreateFailed, params: [
                AnalyticsParam.accountId: request.accountId
            ])
            throw error
        }
    }
}
