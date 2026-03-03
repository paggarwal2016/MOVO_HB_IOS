//
//  ACHViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 03/03/26.
//

import Foundation
import Combine
import MobileBankingSDK

@MainActor
final class ACHViewModel: ObservableObject {
    
    private let service: PlaidService
    
    @Published var state: ModelState = .idle
    
    init(service: PlaidService = .shared) {
        self.service = service
    }
    
    func fetchLinkToken(accountID: Int? = nil) async throws -> GetPlaidLinkTokenResponse {
        guard state != .loading else {
            throw NSError(domain: "Already loading", code: 1)
        }
        state = .loading
        defer { state = .idle }
        do {
            let response: GetPlaidLinkTokenResponse = try await service.getLinkToken(accountID: accountID)
            state = .success
            return response
        } catch {
            state = .failure
            AlertManager.shared.showError(error.localizedDescription)
            throw error
        }
    }
}



enum ModelState: Equatable {
    case idle
    case loading
    case success
    case failure
}
