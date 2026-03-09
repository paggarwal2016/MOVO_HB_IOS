//
//  ACHViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 09/03/26.
//

import Foundation
import Combine
import MobileBankingSDK

@MainActor
final class ACHViewModel: ObservableObject {
    
    private let service: PlaidService
    private let alertManager: AlertManagerProtocol
    
    @Published var state: ModelState = .idle
    
    init(
        service: PlaidService = .shared,
        alertManager: AlertManagerProtocol
    ) {
        self.service = service
        self.alertManager = alertManager
    }
    
    func fetchLinkToken(accountID: Int? = nil) async throws -> GetPlaidLinkTokenResponse {
        guard state != .loading else {
            throw ACHError.alreadyLoading
        }
        state = .loading
        defer { state = .idle }
        do {
            let response: GetPlaidLinkTokenResponse = try await service.getLinkToken(accountID: accountID)
            state = .success
            return response
        } catch {
            state = .failure
            alertManager.showError(error.localizedDescription)
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


enum ACHError: Error {
    case alreadyLoading
}
