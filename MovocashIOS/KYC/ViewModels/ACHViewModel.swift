//
//  ACHViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/03/26.
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
    
    func fetchLinkToken(accountID: Int? = nil) async throws {
        guard state != .loading else { return }
        state = .loading
        do {
            let _: GetPlaidLinkTokenResponse = try await service.getLinkToken(accountID: accountID)
            state = .success
        } catch {
            state = .failure
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
