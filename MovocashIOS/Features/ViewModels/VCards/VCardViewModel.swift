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
    private let primaryCardStore: PrimaryCardStore?

    init(
        network: NetworkServiceProtocol,
        alertManager: AlertManagerProtocol,
        analytics: AnalyticsTracking? = nil,
        primaryCardStore: PrimaryCardStore? = nil
    ) {
        self.network = network
        self.analytics = analytics ?? AnalyticsManager.shared
        self.primaryCardStore = primaryCardStore
        super.init(alertManager: alertManager)
    }

    // MARK: - State

    @Published var apiCards: [VCardListResponse] = []
    @Published var primaryLinkedCard: VCardListResponse? = nil
    @Published var hasLoadedCards: Bool = false

    func loadCards(primaryAccountId: Int? = nil) async {
        do {
            // Only enabled (active) cards are shown and used.
            let all = try await getVCardsAll().filter { $0.enabled == true }
            if let accountId = primaryAccountId {
                primaryLinkedCard = all.first { $0.savingsAccountId == accountId }
                apiCards = all.filter { $0.savingsAccountId != accountId }
            } else {
                primaryLinkedCard = nil
                apiCards = all
            }
            if let primaryLinkedCard { primaryCardStore?.update(primaryLinkedCard) }
        } catch {
            // Error already surfaced by perform(_:) in getVCardsAll
        }
        hasLoadedCards = true
    }
    
    var cards: [VCardListResponse] { apiCards }

    // MARK: - Vcard get

    func getVCardPrimary() async throws -> VCardPrimaryResponse? {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.getVCardsPrimary)
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else {
                return nil
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let card = try JSONDecoder().decode(VCardsList.self, from: plainData)
            analytics.log(AnalyticsEvent.vcardViewed)
            return VCardPrimaryResponse(success: true, message: envelope.message, data: card)
        } catch NetworkError.noContent {
            return nil
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    func fetchPrimaryCard() async throws -> VCardListResponse? {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.getVCardsPrimary)
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else { return nil }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let card = try JSONDecoder().decode(VCardListResponse.self, from: plainData)
            primaryCardStore?.update(card)
            analytics.log(AnalyticsEvent.vcardViewed)
            return card
        } catch NetworkError.noContent {
            return nil
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    // MARK: - Vcard All

    func getVCardsList() async throws -> [VCardsList] {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.getVCardsList)
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else {
                throw NetworkError.decodingError
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let cards = try JSONDecoder().decode([VCardsList].self, from: plainData)
            analytics.log(AnalyticsEvent.vcardViewed)
            return cards
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    func getVCardsAll() async throws -> [VCardListResponse] {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.getVCardsList)
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else {
                throw NetworkError.decodingError
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let cards = try JSONDecoder().decode([VCardListResponse].self, from: plainData)
            analytics.log(AnalyticsEvent.vcardViewed)
            return cards
        } catch {
            analytics.log(AnalyticsEvent.vcardFetchFailed)
            throw error
        }
    }

    // MARK: - Vcard post

    func postVCard(request: VCardsRequest) async throws -> VCardsList {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.postVCards(request: request))
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else {
                throw NetworkError.decodingError
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let card = try JSONDecoder().decode(VCardsList.self, from: plainData)
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
    
    func createVCard(request: CreateVCardRequest) async throws -> VCardListResponse {
        do {
            let envelope: CreateVCardEncryptedResponse = try await perform {
                try await self.network.request(VCardAPI.createVCard(request: request))
            }
            guard let encryptedBase64 = envelope.data?.encryptedData else {
                throw NetworkError.decodingError
            }
            let plainData = try SealedCryptoService.decrypt(encryptedBase64: encryptedBase64)
#if DEBUG
            if let json = String(data: plainData, encoding: .utf8) {
                print("[VCard decrypt]", json)
            }
#endif
            let card = try JSONDecoder().decode(VCardListResponse.self, from: plainData)
            analytics.log(AnalyticsEvent.vcardCreated)
            return card
        } catch {
            analytics.log(AnalyticsEvent.vcardCreateFailed, params: [
                AnalyticsParam.errorCode: error.analyticsCode, AnalyticsParam.errorMessage: error.localizedDescription
            ])
            throw error
        }
    }
}
