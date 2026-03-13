//
//  BaseViewModel.swift
//  MovocashIOS
//
//  Created by Vinu on 13/03/26.
//

import Foundation
import Combine

@MainActor
class BaseViewModel: ObservableObject {
    
    // MARK: - Published
    
    @Published private(set) var state: AuthState = .idle
    
    // MARK: - Dependencies
    
    private let alertManager: AlertManagerProtocol
    
    // MARK: - Init
    
    init(alertManager: AlertManagerProtocol) {
        self.alertManager = alertManager
    }
    
    // MARK: - Perform
    
    func perform<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
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
    case deallocated

    var errorDescription: String? {
        switch self {
        case .alreadyLoading: return "A request is already in progress."
        case .deallocated:    return "The view model was deallocated."
        }
    }
}
