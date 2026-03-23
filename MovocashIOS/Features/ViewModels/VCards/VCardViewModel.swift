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
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        super.init(alertManager: alertManager)
    }
    
    // MARK: - Vcard get
    
    func getVCard() async throws -> VCardsResponse {
        try await perform { try await self.network.request(VCardAPI.getVCards) }
    }
    
    // MARK: - Vcard post

    func postVCard(request: VCardsRequest) async throws -> VCardsResponse {
        try await perform { try await self.network.request(VCardAPI.postVCards(request: request)) }
    }

    // MARK: - Reveal Card

    func revealCard(pin: String, onSuccess: @escaping (VCardsResponse) -> Void) async {
        do {
            let response: VCardsResponse = try await perform { [weak self] in
                guard let self else { throw ModelError.deallocated }
                return try await network.request(VCardAPI.postVCards(request: VCardsRequest(pin: pin)))
            }
            onSuccess(response)
        } catch is CancellationError {
            // cancelled — no action
        } catch {
            // error surfaced via BaseViewModel toast
        }
    }
}
