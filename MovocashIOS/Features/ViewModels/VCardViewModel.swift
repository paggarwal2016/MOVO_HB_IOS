//
//  VCardViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 12/03/26.
//

import Foundation
import Combine

final class VCardViewModel: ObservableObject {
    @Published var state: AuthState = .idle
    
    private let network: NetworkServiceProtocol
    private let alertManager: AlertManagerProtocol
    
    init(network: NetworkServiceProtocol,
         alertManager: AlertManagerProtocol) {
        self.network = network
        self.alertManager = alertManager
    }
    
    // MARK: - Vcard get
    
    func getVCard() async throws -> VCardsResponse {
        try await perform { try await self.network.request(VCardAPI.getVCards) }
    }
    
    // MARK: - Vcard post
    
    func postVCard(request: VCardsRequest) async throws -> VCardsResponse {
        try await perform { try await self.network.request(VCardAPI.postVCards(request: request)) }
    }
    
    // MARK: - Private
    
    private func perform<T>(_ operation: () async throws -> T) async throws -> T {
         guard state != .loading else { throw ModelError.alreadyLoading }
         state = .loading
         do {
             let result = try await operation()
             state = .success
             return result
         } catch is CancellationError {
             state = .idle
             throw CancellationError()
         } catch {
             state = .idle
             alertManager.showError(error.localizedDescription)
             throw error
         }
     }
    
}







// MARK: - ViewModel Error

enum ModelError: LocalizedError {
    case alreadyLoading

    var errorDescription: String? {
        switch self {
        case .alreadyLoading: return "A request is already in progress."
        }
    }
}
